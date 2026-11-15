import { Suspense } from "react";
import ParentProfilePage from "@/components/ParentProfilePage";

export default function Page() {
  return (
    <Suspense fallback={null}>
      <ParentProfilePage />
    </Suspense>
  );
}
