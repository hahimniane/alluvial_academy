import { Suspense } from "react";
import ParentConversationPage from "@/components/ParentConversationPage";

export default function Page() {
  return (
    <Suspense>
      <ParentConversationPage />
    </Suspense>
  );
}
