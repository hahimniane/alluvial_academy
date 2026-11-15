import { Suspense } from "react";
import { ParentPayReturnPage } from "@/components/ParentPayPage";

export default function Page() {
  return (
    <Suspense>
      <ParentPayReturnPage />
    </Suspense>
  );
}
