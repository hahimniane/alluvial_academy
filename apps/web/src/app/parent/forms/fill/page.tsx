import { Suspense } from "react";
import ParentFormFillPage from "@/components/ParentFormFillPage";

export default function Page() {
  return (
    <Suspense fallback={null}>
      <ParentFormFillPage />
    </Suspense>
  );
}
