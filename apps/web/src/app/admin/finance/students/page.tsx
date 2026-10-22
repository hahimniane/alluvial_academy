"use client";

import { Suspense } from "react";
import { FinancePlaceholder, FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceStudentsPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinancePlaceholder title="New students & first invoices" />
      </FinanceShell>
    </Suspense>
  );
}
