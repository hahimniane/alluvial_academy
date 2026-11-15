"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { useEffect, useState } from "react";
import { auth } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell } from "@/components/TeacherDashboardHome";
import { MySubmissionsView } from "@/components/forms/MySubmissionsView";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

const defaultSummary = {displayName: "Teacher", firstName: "Teacher", initials: "TE"};

export function TeacherFormSubmissionsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState(defaultSummary);
  const [currentUser, setCurrentUser] = useState<User | null>(null);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setCurrentUser(null);
        setAccess("signedOut");
        return;
      }

      setAccess("checking");
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          return;
        }
        const userRecord = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        setCurrentUser(nextUser);
        setSummary(summaryForUser(nextUser, userRecord));
        setAccess("allowed");
      } catch {
        if (mounted) setAccess("denied");
      }
    });
  }, []);

  if (access !== "allowed" || !currentUser) return <TeacherAccessPrompt access={access === "allowed" ? "checking" : access} />;

  return (
    <TeacherShell activeLabel="My Form Submissions" breadcrumb="Forms / My Form Submissions" summary={summary}>
      <MySubmissionsView user={currentUser} backHref="/teacher/" />
    </TeacherShell>
  );
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function summaryForUser(user: User, data: Record<string, unknown> | null) {
  const firstName = stringValue(data?.first_name ?? data?.firstName);
  const lastName = stringValue(data?.last_name ?? data?.lastName);
  const displayName = [firstName, lastName].filter(Boolean).join(" ") || user.displayName || user.email || "Teacher";
  const parts = displayName.replace(/@.*/, "").split(/[^a-zA-Z0-9]+/).filter(Boolean);
  return {
    displayName,
    firstName: firstName || parts[0] || "Teacher",
    initials: parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE",
  };
}

