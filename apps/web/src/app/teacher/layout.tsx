import type { ReactNode } from "react";
import { TeacherRouteGate } from "@/components/TeacherRouteGate";

export const metadata = {
  robots: { index: false, follow: false },
};

/**
 * The teacher console lives in the Flutter app. TeacherRouteGate renders the
 * routes Flutter embeds and forwards the rest to /app/.
 */
export default function TeacherLayout({ children }: { children: ReactNode }) {
  return <TeacherRouteGate>{children}</TeacherRouteGate>;
}
