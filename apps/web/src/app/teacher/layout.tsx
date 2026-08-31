import type { ReactNode } from "react";
import { FlutterRedirect } from "@/components/FlutterRedirect";

export const metadata = {
  robots: { index: false, follow: false },
};

/**
 * The teacher console lives in the Flutter app now, so every /teacher/* route
 * forwards to /app/ instead of rendering the retired Next.js teacher pages.
 */
export default function TeacherLayout({ children }: { children: ReactNode }) {
  void children; // intentionally not rendered — bounce to the Flutter app
  return <FlutterRedirect />;
}
