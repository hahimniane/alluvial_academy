import { Suspense } from "react";
import ParentFormsPage from "@/components/ParentFormsPage";

export default function Page() {
  return (
    <Suspense fallback={null}>
      <ParentFormsPage />
    </Suspense>
  );
}
