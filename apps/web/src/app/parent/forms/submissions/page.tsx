import { Suspense } from "react";
import ParentSubmissionsPage from "@/components/ParentSubmissionsPage";

export default function Page() {
  return (
    <Suspense fallback={null}>
      <ParentSubmissionsPage />
    </Suspense>
  );
}
