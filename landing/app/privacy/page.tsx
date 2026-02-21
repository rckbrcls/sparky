import type { Metadata } from "next";
import { Separator } from "@/components/ui/separator";

export const metadata: Metadata = {
  title: "Privacy Policy | Sparky",
  description:
    "Sparky is a privacy-first app. No accounts, no cloud, no tracking. Your data stays on your device.",
};

export default function PrivacyPage() {
  return (
    <main className="mx-auto max-w-3xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8">
      <h1 className="font-serif text-4xl font-bold tracking-tight">
        Privacy Policy
      </h1>
      <p className="mt-2 text-sm text-muted-foreground">
        Last updated: February 21, 2026
      </p>

      <Separator className="my-8" />

      <div className="prose prose-neutral dark:prose-invert max-w-none space-y-8 text-foreground">
        <section>
          <h2 className="font-serif text-2xl font-bold">Overview</h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            Sparky is a privacy-first personal memory and reminder app. It
            requires no accounts, no cloud services, and no internet connection
            to function. All your data lives exclusively on your device. This
            policy explains what data Sparky accesses, why, and how it is
            stored.
          </p>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">
            Information We Do Not Collect
          </h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            Sparky does <strong>not</strong> collect, transmit, or store any
            personal information on external servers. Specifically, we do not
            collect:
          </p>
          <ul className="mt-3 list-disc space-y-1 pl-6 text-muted-foreground">
            <li>Names, email addresses, or contact information</li>
            <li>Usage analytics or behavioral data</li>
            <li>Device identifiers or advertising IDs</li>
            <li>Location history or movement patterns</li>
            <li>Content of your memories, notes, or checklists</li>
            <li>Any data whatsoever sent to our servers (we have none)</li>
          </ul>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">Data Storage</h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            All data you create in Sparky (memories, checklists, attachments,
            reminders, and settings) is stored locally on your device using
            Apple&apos;s SwiftData framework. No data is transmitted to any
            server. There is no cloud sync, no backup service, and no remote
            database. Your data exists solely within the app&apos;s sandboxed
            storage on your iPhone.
          </p>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">
            Device Permissions
          </h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            Sparky may request the following device permissions. Each is
            optional and used only for features you choose to use:
          </p>
          <div className="mt-4 space-y-4">
            <div>
              <h3 className="font-semibold">Camera</h3>
              <p className="text-sm text-muted-foreground">
                Used to capture photos and attach them directly to memories.
                Photos are saved locally within the app.
              </p>
            </div>
            <div>
              <h3 className="font-semibold">Microphone</h3>
              <p className="text-sm text-muted-foreground">
                Used to record audio notes that you can attach to memories.
                Recordings are stored locally.
              </p>
            </div>
            <div>
              <h3 className="font-semibold">Photo Library</h3>
              <p className="text-sm text-muted-foreground">
                Used to select existing photos from your library to attach to
                memories. Selected photos are copied into the app&apos;s local
                storage.
              </p>
            </div>
            <div>
              <h3 className="font-semibold">Speech Recognition</h3>
              <p className="text-sm text-muted-foreground">
                Used to transcribe audio recordings into text. Processing is
                handled on-device by Apple&apos;s Speech framework.
              </p>
            </div>
            <div>
              <h3 className="font-semibold">Location</h3>
              <p className="text-sm text-muted-foreground">
                Used for location-based reminders. Sparky monitors geofence
                regions you define so it can notify you when you arrive at or
                leave a place. Your location is never transmitted anywhere.
                All geofence monitoring happens on-device via Apple&apos;s Core
                Location.
              </p>
            </div>
            <div>
              <h3 className="font-semibold">Notifications</h3>
              <p className="text-sm text-muted-foreground">
                Used to deliver scheduled reminders and location-triggered
                alerts. Notifications are scheduled locally through Apple&apos;s
                UserNotifications framework.
              </p>
            </div>
          </div>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">
            Apple Privacy Manifest
          </h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            In compliance with Apple&apos;s privacy requirements, Sparky declares
            the following in its Privacy Manifest:
          </p>
          <ul className="mt-3 list-disc space-y-1 pl-6 text-muted-foreground">
            <li>
              <strong>UserDefaults (CA92.1):</strong> Used to store app
              preferences and settings locally.
            </li>
            <li>
              <strong>File timestamp (C617.1):</strong> Used for managing
              attachment file metadata.
            </li>
            <li>
              <strong>Tracking:</strong> Sparky does not track users. The
              NSPrivacyTracking flag is set to false.
            </li>
            <li>
              <strong>Collected data:</strong> None. The
              NSPrivacyCollectedDataTypes array is empty.
            </li>
          </ul>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">
            Third-Party Services
          </h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            Sparky uses <strong>zero</strong> third-party services, SDKs, or
            analytics tools. There are no external dependencies that process
            your data. The app communicates with no servers whatsoever.
          </p>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">Data Deletion</h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            You can delete any memory, attachment, or checklist directly within
            the app at any time. To remove all Sparky data completely, simply
            uninstall the app from your device. Since no data exists outside
            your device, uninstalling guarantees complete data deletion.
          </p>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">
            Children&apos;s Privacy
          </h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            Sparky does not collect any personal information from anyone,
            including children under the age of 13. Since no data leaves the
            device and no accounts are created, Sparky is inherently compliant
            with children&apos;s privacy regulations.
          </p>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">
            Changes to This Policy
          </h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            If we update this Privacy Policy, we will post the revised version
            on this page with an updated &ldquo;Last updated&rdquo; date. Since
            Sparky collects no data, changes are unlikely to affect your
            privacy in any meaningful way.
          </p>
        </section>

        <section>
          <h2 className="font-serif text-2xl font-bold">Contact</h2>
          <p className="mt-2 leading-relaxed text-muted-foreground">
            If you have any questions about this Privacy Policy, contact us at{" "}
            <a
              href="mailto:contact@polterware.com"
              className="text-foreground underline underline-offset-4 hover:text-primary"
            >
              contact@polterware.com
            </a>
            .
          </p>
        </section>
      </div>
    </main>
  );
}
