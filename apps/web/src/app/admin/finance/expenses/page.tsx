"use client";

import { Suspense } from "react";
import { ExpensesScreen } from "@/components/finance/ExpensesScreen";
import { FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceExpensesPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <ExpensesScreen />
      </FinanceShell>
    </Suspense>
  );
}
