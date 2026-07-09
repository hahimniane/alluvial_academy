import type { Metadata, Viewport } from "next";
import { Suspense } from "react";
import { AnalyticsTracker } from "@/components/AnalyticsTracker";
import "./globals.css";

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
    <html lang="en">
      <body>
        <Suspense fallback={null}>
          <AnalyticsTracker />
        </Suspense>
        {children}
      </body>
    </html>
  );
}
