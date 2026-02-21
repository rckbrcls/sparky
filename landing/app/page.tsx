import { HeroSection } from "@/components/sections/hero-section";
import { FeaturesSection } from "@/components/sections/features-section";
import { PrivacyHighlightSection } from "@/components/sections/privacy-highlight-section";
import { CtaSection } from "@/components/sections/cta-section";

export default function Page() {
  return (
    <>
      <HeroSection />
      <FeaturesSection />
      <PrivacyHighlightSection />
      <CtaSection />
    </>
  );
}
