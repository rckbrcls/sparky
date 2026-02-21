import type { Metadata } from "next";
import { Inter, Libre_Baskerville } from "next/font/google";
import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-sans" });

const libreBaskerville = Libre_Baskerville({
  subsets: ["latin"],
  weight: ["400", "700"],
  variable: "--font-serif",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://sparky-app.com"),
  title: "Sparky | Your Second Brain, Always With You",
  description:
    "Capture thoughts, set smart reminders, and organize everything that matters. Privately, on your device. No accounts, no cloud, no tracking.",
  openGraph: {
    title: "Sparky | Your Second Brain, Always With You",
    description:
      "Capture thoughts, set smart reminders, and organize everything that matters. Privately, on your device.",
    type: "website",
    images: [{ url: "/sparky-icon.png", width: 1024, height: 1024 }],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${libreBaskerville.variable}`}
    >
      <body className="antialiased">
        <Header />
        <main className="min-h-screen">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
