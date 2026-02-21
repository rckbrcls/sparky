import {
  Brain,
  CalendarDays,
  Bell,
  MapPin,
  Paperclip,
  CheckSquare,
} from "lucide-react";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";

const features = [
  {
    icon: Brain,
    title: "Minds",
    description:
      "Organize memories into hierarchical categories with custom icons and colors.",
  },
  {
    icon: CalendarDays,
    title: "Calendar Timeline",
    description:
      "Browse memories on a visual timeline by day, week, or month.",
  },
  {
    icon: Bell,
    title: "Smart Reminders",
    description:
      "One-time or recurring notifications: daily, weekly, monthly, custom.",
  },
  {
    icon: MapPin,
    title: "Location Triggers",
    description: "Get reminded when arriving at or leaving a place.",
  },
  {
    icon: Paperclip,
    title: "Rich Attachments",
    description:
      "Photos, audio recordings, files, and links on any memory.",
  },
  {
    icon: CheckSquare,
    title: "Checklists",
    description:
      "Break memories into actionable items, track completion.",
  },
];

export function FeaturesSection() {
  return (
    <section id="features" className="px-4 py-16 sm:py-24">
      <div className="mx-auto max-w-6xl">
        <h2 className="text-center font-serif text-3xl font-bold tracking-tight sm:text-4xl">
          Everything you need to remember
        </h2>
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <Card key={feature.title}>
              <CardHeader>
                <feature.icon className="mb-2 h-8 w-8 text-primary" />
                <CardTitle>{feature.title}</CardTitle>
                <CardDescription>{feature.description}</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
