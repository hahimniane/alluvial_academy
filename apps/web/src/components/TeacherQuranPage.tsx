"use client";

import { onAuthStateChanged } from "firebase/auth";
import { useEffect, useState } from "react";
import { auth } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell } from "@/components/TeacherDashboardHome";
import { QuranReaderPage, type AccessState } from "@/components/QuranReaderPage";

type TeacherSummary = { displayName: string; firstName: string; initials: string };

function summaryForUser(displayName: string, email: string): TeacherSummary {
  const name = displayName.trim() || email.split("@")[0] || "Teacher";
  const parts = name.split(/\s+/).filter(Boolean);
  const initials = parts.slice(0, 2).map((p) => p[0]?.toUpperCase() ?? "").join("") || "TE";
  return { displayName: name, firstName: parts[0] ?? name, initials };
}

/**
 * The Qur'an for teachers — the same reader students use, and the same one the
 * Flutter app opens for every role. Memorization is keyed by uid, so a teacher
 * tracks their own progress.
 */
export function TeacherQuranPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [uid, setUid] = useState<string | null>(null);
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setAccess("signedOut");
        setUid(null);
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
        const record = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        const first = String((record as Record<string, unknown>)?.first_name ?? "").trim();
        const last = String((record as Record<string, unknown>)?.last_name ?? "").trim();
        setSummary(summaryForUser(`${first} ${last}`.trim() || nextUser.displayName || "", nextUser.email ?? ""));
        setUid(nextUser.uid);
        setAccess("allowed");
      } catch {
        if (mounted) setAccess("denied");
      }
    });
  }, []);

  return (
    <QuranReaderPage
      session={{ access, uid }}
      accessPrompt={<TeacherAccessPrompt access={access} />}
      renderShell={(children) => (
        <TeacherShell activeLabel="Quran" breadcrumb="Communication / Quran" summary={summary}>
          {children}
        </TeacherShell>
      )}
    />
  );
}

export default TeacherQuranPage;
