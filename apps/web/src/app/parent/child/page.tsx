import { Suspense } from "react";
import ParentChildPage from "@/components/ParentChildPage";

export default function Page() {
  return (
    <Suspense>
      <ParentChildPage />
    </Suspense>
  );
}
