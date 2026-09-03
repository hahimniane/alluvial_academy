"use client";

import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { FlutterRedirect } from "@/components/FlutterRedirect";

/**
 * The admin console is moving to Next.js one module at a time. Routes listed
 * here render natively; everything else under /admin/ still forwards to the
 * Flutter app.
 */
const NATIVE_ADMIN_PREFIXES = ["/admin/shifts", "/admin/student-applicants"];

export function AdminRouteGate({ children }: { children: ReactNode }) {
  const pathname = usePathname() ?? "";
  const isNative = NATIVE_ADMIN_PREFIXES.some((prefix) => pathname.startsWith(prefix));
  if (!isNative) return <FlutterRedirect />;
  return <>{children}</>;
}
