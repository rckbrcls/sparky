import Link from "next/link";
import { Button } from "@/components/ui/button";

export function CtaSection() {
  return (
    <section className="px-4 py-16 text-center sm:py-24">
      <h2 className="font-serif text-3xl font-bold tracking-tight sm:text-4xl">
        Ready to spark your memory?
      </h2>
      <p className="mt-4 text-muted-foreground">
        Download Sparky for free on the App Store.
      </p>
      <Button asChild size="lg" className="mt-8">
        <Link href="https://apps.apple.com/app/sparky/id000000000">
          Download on App Store
        </Link>
      </Button>
    </section>
  );
}
