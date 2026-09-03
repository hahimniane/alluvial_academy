"use client";

import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { FlutterRedirect } from "@/components/FlutterRedirect";

/**
 * The teacher console lives in the Flutter app. A route listed here is the
 * exception: it renders natively so the Flutter screen can embed it, the same
 * way the admin console embeds Shifts and Student Applicants. Everything else
 * under /teacher/ still forwards to /app/.
 */
const NATIVE_TEACHER_PREFIXES = ["/teacher/job-board"];

export function TeacherRouteGate({ children }: { children: ReactNode }) {
  const pathname = usePathname() ?? "";
  const isNative = NATIVE_TEACHER_PREFIXES.some((prefix) => pathname.startsWith(prefix));
  if (!isNative) return <FlutterRedirect />;
  return <>{children}</>;
}
