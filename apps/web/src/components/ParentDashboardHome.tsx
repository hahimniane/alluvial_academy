"use client";

import { useParentSession } from "@/components/ParentArea";

/**
 * The parent home (ParentDashboardScreen). A-031: "Welcome, {first_name}", or
 * "Parent Dashboard" without a first name — English in both languages, as in
 * Flutter.
 */
export default function ParentDashboardHome() {
  const session = useParentSession();
  return (
    <div className="p-4">
      <h1 className="text-[22px] font-extrabold text-[#111827]">{session.greeting}</h1>
    </div>
  );
}
