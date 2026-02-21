import { Shield, ServerOff, EyeOff, WifiOff } from "lucide-react";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";

const highlights = [
  {
    icon: ServerOff,
    title: "No Cloud",
    description:
      "All your data stays on your device. No servers, no sync, no risk.",
  },
  {
    icon: EyeOff,
    title: "No Tracking",
    description:
      "Zero analytics, no third-party SDKs. We don't know how you use the app.",
  },
  {
    icon: WifiOff,
    title: "No Accounts",
    description:
      "No sign-up, no email, no password. Just open and start using Sparky.",
  },
];

export function PrivacyHighlightSection() {
  return (
    <section className="bg-muted/50 px-4 py-16 sm:py-24">
      <div className="mx-auto max-w-4xl text-center">
        <Shield className="mx-auto mb-4 h-10 w-10 text-primary" />
        <h2 className="font-serif text-3xl font-bold tracking-tight sm:text-4xl">
          Your data stays yours
        </h2>
        <div className="mt-12 grid gap-6 sm:grid-cols-3">
          {highlights.map((item) => (
            <Card key={item.title}>
              <CardHeader className="items-center justify-items-center text-center">
                <item.icon className="mb-2 h-8 w-8 text-muted-foreground" />
                <CardTitle>{item.title}</CardTitle>
                <CardDescription>{item.description}</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
