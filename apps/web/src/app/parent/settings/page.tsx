import { Suspense } from "react";
import ParentSettingsPage from "@/components/ParentSettingsPage";

export default function Page() {
  return (
    <Suspense fallback={null}>
      <ParentSettingsPage />
    </Suspense>
  );
}
