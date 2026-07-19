#!/bin/bash

set -euo pipefail

APP_DISPLAY_NAME="Sparky"
REPO="rckbrcls/sparky"
GITHUB_API="https://api.github.com/repos/${REPO}/releases"

usage() {
  cat << EOF
Usage: install.sh [--version <version>]

Options:
  --version <version>  Install a specific version (ex: 0.0.1)
  -h, --help           Show this help
EOF
}

VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer only supports macOS."
  exit 1
fi

if [ -n "$VERSION" ]; then
  VERSION="${VERSION#v}"
  RELEASE_URL="${GITHUB_API}/tags/v${VERSION}"
else
  RELEASE_URL="${GITHUB_API}/latest"
fi

TMP_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fetch_release_json() {
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$RELEASE_URL"
}

select_asset() {
  local arch json
  arch=$(uname -m)
  json=$(cat)

  printf '%s' "$json" | python3 -c '
import json
import sys

arch = sys.argv[1]

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    print("ERROR: Failed to parse GitHub API response.", file=sys.stderr)
    sys.exit(2)

assets = data.get("assets", [])
if not assets:
    print("ERROR: No assets found in this release.", file=sys.stderr)
    sys.exit(3)

# Prefer universal builds, otherwise pick architecture-specific asset.
preferred = []
for asset in assets:
    name = asset.get("name", "")
    if not name.endswith(".zip"):
        continue
    lowered = name.lower()
    if "universal" in lowered:
        preferred.append(asset)

if not preferred:
    for asset in assets:
        name = asset.get("name", "")
        if not name.endswith(".zip"):
            continue
        lowered = name.lower()
        if arch in ("arm64", "aarch64") and "arm64" in lowered:
            preferred.append(asset)
        elif arch == "x86_64" and "x86_64" in lowered:
            preferred.append(asset)

if not preferred:
    for asset in assets:
        name = asset.get("name", "")
        if name.endswith(".zip"):
            preferred.append(asset)
            break

if not preferred:
    print("ERROR: Could not find a .zip asset to download.", file=sys.stderr)
    sys.exit(4)

asset = preferred[0]
print(json.dumps({
    "name": asset.get("name"),
    "url": asset.get("browser_download_url"),
    "size": asset.get("size"),
}))
' "$arch"
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required to parse GitHub API responses."
  exit 1
fi

echo "Fetching release metadata..."
RELEASE_JSON=$(fetch_release_json || true)
if [ -z "$RELEASE_JSON" ]; then
  echo "Failed to fetch release metadata from GitHub."
  exit 1
fi

ASSET_JSON=$(echo "$RELEASE_JSON" | select_asset)
ASSET_NAME=$(echo "$ASSET_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')
ASSET_URL=$(echo "$ASSET_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["url"])')
ASSET_SIZE=$(echo "$ASSET_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["size"])')

if [ -z "$ASSET_URL" ] || [ -z "$ASSET_NAME" ]; then
  echo "Failed to resolve a release asset to download."
  exit 1
fi

ZIP_PATH="$TMP_DIR/$ASSET_NAME"

echo "Downloading $ASSET_NAME..."
if ! curl -fL "$ASSET_URL" -o "$ZIP_PATH"; then
  echo "Failed to download release asset."
  exit 1
fi

if [ -n "$ASSET_SIZE" ]; then
  DOWNLOADED_SIZE=$(stat -f%z "$ZIP_PATH")
  if [ "$DOWNLOADED_SIZE" -ne "$ASSET_SIZE" ]; then
    echo "Downloaded file size mismatch (expected $ASSET_SIZE, got $DOWNLOADED_SIZE)."
    exit 1
  fi
fi

EXTRACT_DIR="$TMP_DIR/extract"
mkdir -p "$EXTRACT_DIR"

echo "Extracting..."
if ! ditto -x -k "$ZIP_PATH" "$EXTRACT_DIR"; then
  echo "Failed to extract zip."
  exit 1
fi

APP_PATH=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" -print -quit)
if [ -z "$APP_PATH" ]; then
  echo "No .app bundle found in the archive."
  exit 1
fi

APP_BUNDLE_NAME=$(basename "$APP_PATH")

TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
fi

TARGET_PATH="$TARGET_DIR/$APP_BUNDLE_NAME"

if [ -d "$TARGET_PATH" ]; then
  echo "Removing existing $TARGET_PATH"
  rm -rf "$TARGET_PATH"
fi

echo "Installing to $TARGET_DIR"
if ! ditto "$APP_PATH" "$TARGET_PATH"; then
  echo "Failed to install the app bundle."
  exit 1
fi

if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$TARGET_PATH" 2>/dev/null || true
fi

echo "✅ ${APP_DISPLAY_NAME} installed at $TARGET_PATH"
if [ "$TARGET_DIR" != "/Applications" ]; then
  echo "Note: Installed to $TARGET_DIR because /Applications is not writable."
fi

echo "Open with: open \"$TARGET_PATH\""
