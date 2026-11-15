import type { ReactNode } from "react";
import { ParentArea } from "@/components/ParentArea";
import "./parent.css";

export const metadata = {
  robots: { index: false, follow: false },
};

/**
 * The parent area. ParentArea admits a signed-in parent opening as parent whom
 * settings/parent_web_cutover has moved, and hands everyone else to /app/. The
 * shell lives here rather than in each page so the sidebar keeps its state
 * while a parent moves between pages.
 */
export default function ParentLayout({ children }: { children: ReactNode }) {
  return (
    <div className="parent-area">
      <ParentArea>{children}</ParentArea>
    </div>
  );
}
