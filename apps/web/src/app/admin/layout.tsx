import type { ReactNode } from "react";
import { AdminRouteGate } from "@/components/AdminRouteGate";

export const metadata = {
  robots: { index: false, follow: false },
};

/**
 * The admin console is migrating from Flutter to Next.js module by module.
 * AdminRouteGate renders the migrated routes natively and forwards the rest
 * to the Flutter app at /app/.
 */
export default function AdminLayout({ children }: { children: ReactNode }) {
  return <AdminRouteGate>{children}</AdminRouteGate>;
}
