import Link from "next/link";
import { Separator } from "@/components/ui/separator";

export function Footer() {
  return (
    <footer className="w-full">
      <Separator />
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-4 px-4 py-8 sm:flex-row sm:justify-between sm:px-6 lg:px-8">
        <div className="flex items-center gap-2">
          <span className="font-serif font-bold">Sparky</span>
          <span className="text-sm text-muted-foreground">© 2026</span>
          <span className="text-sm text-muted-foreground">·</span>
          <a
            href="https://www.polterware.com/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            Made by Polterware
          </a>
        </div>
        <nav className="flex items-center gap-6">
          <Link
            href="/privacy"
            className="text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            Privacy Policy
          </Link>
          <Link
            href="https://apps.apple.com/app/sparky/id000000000"
            className="text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            App Store
          </Link>
        </nav>
      </div>
    </footer>
  );
}
