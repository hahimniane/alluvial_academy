import { Suspense } from "react";
import ParentInvoicesPage from "@/components/ParentInvoicesPage";

export default function Page() {
  return (
    <Suspense>
      <ParentInvoicesPage />
    </Suspense>
  );
}
