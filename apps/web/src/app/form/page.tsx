import { Suspense } from "react";
import { PublicFormPage } from "@/components/PublicFormPage";

export const metadata = {
  title: "Form — Alluwal Education Hub",
  robots: { index: false, follow: false },
};

/**
 * A form's shared link: /form/?id=<templateId>. Admins copy it from Forms in
 * the app and share it, e.g. on WhatsApp.
 */
export default function Page() {
  return (
    <Suspense fallback={null}>
      <PublicFormPage />
    </Suspense>
  );
}
