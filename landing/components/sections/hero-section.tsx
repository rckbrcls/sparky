import Link from "next/link";
import Image from "next/image";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export function HeroSection() {
  return (
    <section className="hero-gradient flex flex-col items-center px-4 pt-24 pb-16 text-center sm:pt-32 sm:pb-24">
      <Badge variant="secondary" className="mb-6">
        Available on iOS
      </Badge>
      <h1 className="font-serif text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
        Your second brain,
        <br />
        always with you.
      </h1>
      <p className="mt-6 max-w-xl text-lg text-muted-foreground">
        Capture thoughts, set smart reminders, and organize everything that
        matters. Privately, on your device.
      </p>
      <div className="mt-8 flex flex-col gap-3 sm:flex-row">
        <Button asChild size="lg">
          <Link href="https://apps.apple.com/app/sparky/id000000000">
            Download on App Store
          </Link>
        </Button>
        <Button asChild variant="ghost" size="lg">
          <a href="#features">Learn More</a>
        </Button>
      </div>
      <div className="mt-12">
        <Image
          src="/sparky-icon.png"
          alt="Sparky App Icon"
          width={180}
          height={180}
          className="rounded-[40px] shadow-2xl"
          priority
        />
      </div>
    </section>
  );
}
