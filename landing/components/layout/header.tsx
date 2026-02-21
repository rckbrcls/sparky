import Link from "next/link";
import Image from "next/image";
import { Button } from "@/components/ui/button";

export function Header() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/80 backdrop-blur-lg">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <Link href="/" className="flex items-center gap-2">
          <Image
            src="/sparky-icon.png"
            alt="Sparky"
            width={32}
            height={32}
            className="rounded-lg"
          />
          <span className="font-serif text-lg font-bold">Sparky</span>
        </Link>
        <nav className="hidden items-center gap-6 sm:flex">
          <Link
            href="/#features"
            className="text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            Features
          </Link>
          <Link
            href="/privacy"
            className="text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            Privacy
          </Link>
          <Button asChild size="sm">
            <Link href="https://apps.apple.com/app/sparky/id000000000">
              Download
            </Link>
          </Button>
        </nav>
      </div>
    </header>
  );
}
