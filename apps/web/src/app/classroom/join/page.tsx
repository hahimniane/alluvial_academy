import { Suspense } from "react";
import { GuestClassroomJoinPage } from "@/components/GuestClassroomJoinPage";

export default function GuestClassroomJoinRoute() {
  return (
    <Suspense fallback={<div className="grid min-h-screen place-items-center bg-[#F8FAFC] text-sm font-semibold text-[#475569]">Joining class...</div>}>
      <GuestClassroomJoinPage />
    </Suspense>
  );
}
