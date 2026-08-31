import { Suspense } from "react";
import { StudentClassroomPage } from "@/components/StudentClassroomPage";

export default function Page() {
  return (
    <Suspense>
      <StudentClassroomPage />
    </Suspense>
  );
}
