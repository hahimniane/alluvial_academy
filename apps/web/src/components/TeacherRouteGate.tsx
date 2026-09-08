"use client";

import type { ReactNode } from "react";

/**
 * The teacher console is the Next.js app.
 *
 * Teachers on the web are sent here from the Flutter shell after sign-in, the
 * same way students go to /student/. Nothing under /teacher/ forwards back to
 * /app/ any more: a teacher who lands on a teacher URL is already where they
 * belong, and each page checks for itself that the signed-in account really is
 * a teacher before rendering anything.
 */
export function TeacherRouteGate({ children }: { children: ReactNode }) {
  return <>{children}</>;
}
