import type { Metadata, Viewport } from "next";
import { Fraunces, Inter } from "next/font/google";
import { Suspense } from "react";
import { AnalyticsTracker } from "@/components/AnalyticsTracker";
import { QuranAmbientPlayer } from "@/components/QuranAmbientPlayer";
import { WhatsAppButton } from "@/components/WhatsAppButton";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-body",
  display: "swap",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-display",
  display: "swap",
  style: ["normal", "italic"],
  axes: ["SOFT", "opsz"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://alluwaleducationhub.org"),
  title: "Alluwal Education Hub",
  description:
    "Online Islamic studies, tutoring, languages, and student support from Alluwal Education Hub.",
  icons: {
    icon: "/favicon.png",
    apple: "/logo-192.png",
  },
  openGraph: {
    title: "Alluwal Education Hub",
    description:
      "Personalized learning, Islamic education, tutoring, and community-centered student support.",
    url: "https://alluwaleducationhub.org",
    siteName: "Alluwal Education Hub",
    images: [{ url: "/logo-512.png", width: 512, height: 512 }],
    type: "website",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#001E4E",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${fraunces.variable}`}>
      <body>
        <Suspense fallback={null}>
          <AnalyticsTracker />
        </Suspense>
        {children}
        <Suspense fallback={null}>
          <QuranAmbientPlayer />
        </Suspense>
        <Suspense fallback={null}>
          <WhatsAppButton />
        </Suspense>
      </body>
    </html>
  );
}
