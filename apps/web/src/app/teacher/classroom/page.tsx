import { Suspense } from "react";
import { TeacherClassroomPage } from "@/components/TeacherClassroomPage";

export default function TeacherClassroomRoute() {
  return (
    <Suspense fallback={<div className="grid min-h-screen place-items-center bg-black text-sm font-semibold text-white">Loading class...</div>}>
      <TeacherClassroomPage />
    </Suspense>
  );
}
