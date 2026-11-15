"use client";

import { useParentSession } from "@/components/ParentArea";
import { QuranReaderPage } from "@/components/QuranReaderPage";

/**
 * Quran (C-330…C-356). The Flutter web sidebar item does nothing today; on
 * phones it opens the same reader every role gets. The plan's default is to
 * open the existing reader, so this is the shared web reader students and
 * teachers use, unchanged, inside the parent shell. Memorization, the goal and
 * the daily log are the signed-in parent's own (`quran_memorization/{uid}`),
 * exactly as on the parent's phone — there is no per-child view anywhere.
 */
export default function ParentQuranPage() {
  const session = useParentSession();
  return (
    // The reader sizes itself for the student/teacher shells; inside the parent
    // content pane it only needs to fill the pane.
    <div className="min-h-full [&>main]:min-h-full">
      <QuranReaderPage session={{ access: "allowed", uid: session.uid }} accessPrompt={null} renderShell={(children) => <>{children}</>} />
    </div>
  );
}
