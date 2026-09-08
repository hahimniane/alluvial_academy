"use client";

import { onAuthStateChanged } from "firebase/auth";
import { useEffect, useState } from "react";
import { auth } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";
import { QuranReaderPage, type AccessState } from "@/components/QuranReaderPage";

/**
 * The Qur'an for students. The reader itself is shared with the teacher page
 * (`QuranReaderPage`) so the two can never drift; this file only resolves the
 * student session and supplies the student shell.
 */
export default function StudentQuranPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(
    () => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" },
  );
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [uid, setUid] = useState<string | null>(null);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        setUid(null);
        return;
      }
      try {
        const session = await resolveStudentSession(nextUser);
        if (!session.isStudent) {
          setAccess("denied");
          return;
        }
        setSummary(session.summary);
        setIsAdultStudent(session.isAdultStudent);
        setAccess("allowed");
        setUid(nextUser.uid);
      } catch {
        setAccess("denied");
      }
    });
  }, []);

  return (
    <QuranReaderPage
      session={{ access, uid }}
      accessPrompt={<StudentAccessPrompt access={access} />}
      renderShell={(children) => (
        <StudentShell activeLabel="Quran" breadcrumb="Learning / Quran" summary={summary} isAdultStudent={isAdultStudent}>
          {children}
        </StudentShell>
      )}
    />
  );
}
