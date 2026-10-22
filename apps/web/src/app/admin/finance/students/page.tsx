"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { NewStudentsScreen } from "@/components/finance/invoices/NewStudentsScreen";

export default function FinanceStudentsPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <NewStudentsScreen />
      </FinanceShell>
    </Suspense>
  );
}
