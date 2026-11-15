import { Suspense } from "react";
import ParentPayPage from "@/components/ParentPayPage";

export default function Page() {
  return (
    <Suspense>
      <ParentPayPage />
    </Suspense>
  );
}
