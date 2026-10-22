"use client";

import { Suspense } from "react";
import { FinanceShell } from "@/components/finance/FinanceShell";
import { FinanceSettingsPage } from "@/components/finance/settings/SettingsPage";

export default function FinanceSettingsRoute() {
  return (
    <Suspense fallback={null}>
      <FinanceShell>
        <FinanceSettingsPage />
      </FinanceShell>
    </Suspense>
  );
}
