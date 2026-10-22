"use client";

import { Suspense } from "react";
import { FinancePlaceholder, FinanceShell } from "@/components/finance/FinanceShell";

export default function FinanceSettingsPage() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinancePlaceholder title="Finance settings" />
      </FinanceShell>
    </Suspense>
  );
}
