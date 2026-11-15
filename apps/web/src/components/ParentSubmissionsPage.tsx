"use client";

import { useMemo } from "react";
import { auth } from "@/lib/firebase";
import { MySubmissionsView } from "@/components/forms/MySubmissionsView";
import { useLocale } from "@/lib/i18n";
import { builtInLayout } from "@/lib/parentForms";
import { parentBuiltIns } from "@/lib/parentFormsData";
import { parentFormsText } from "@/lib/parentFormsText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

/**
 * My Form Submissions (B-142): the shared MySubmissionsScreen view. The two
 * forms built into the app are not in form_templates, so their questions'
 * labels come from the built-in definitions instead of showing field ids.
 */
export default function ParentSubmissionsPage() {
  const fr = useLocale() === "fr";
  const layouts = useMemo(() => {
    const builtIns = parentBuiltIns(parentFormsText(fr));
    return { [builtIns.excuse.id]: builtInLayout(builtIns.excuse), [builtIns.feedback.id]: builtInLayout(builtIns.feedback) };
  }, [fr]);
  const user = auth.currentUser;
  if (!user) return null;
  return (
    <div className="min-h-screen bg-[#F5F7FA]">
      <MySubmissionsView user={user} backHref={PARENT_ROUTES.forms} extraLayouts={layouts} />
    </div>
  );
}
