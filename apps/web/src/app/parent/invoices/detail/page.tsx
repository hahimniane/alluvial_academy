import { Suspense } from "react";
import ParentInvoiceDetailPage from "@/components/ParentInvoiceDetailPage";

export default function Page() {
  return (
    <Suspense>
      <ParentInvoiceDetailPage />
    </Suspense>
  );
}
