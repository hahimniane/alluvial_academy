import { Suspense } from "react";
import ParentClassroomPage from "@/components/ParentClassroomPage";

export default function Page() {
  return (
    <Suspense>
      <ParentClassroomPage />
    </Suspense>
  );
}
