import { expect, test } from "@playwright/test";
import { executeTeacherAction, normalizeWhiteboard } from "../src/components/TeacherTutorPage";

test.describe("teacher AI Tutor protocol", () => {
  test("normalizes Flutter whiteboard version 2 projects", () => {
    const project = normalizeWhiteboard({
      strokes: [{ id: "stroke-1", points: [{ x: 0.25, y: 0.75 }], color: 0xff111827, strokeWidth: 3, normalized: true }],
      texts: [{ id: "text-1", text: "بسم الله", x: 0.5, y: 0.4, normalized: true }],
      version: 2,
    });
    expect(project.version).toBe(2);
    expect(project.strokes).toEqual([{ id: "stroke-1", points: [{ x: 0.25, y: 0.75 }], color: 0xff111827, strokeWidth: 3, normalized: true }]);
    expect(project.texts[0]).toMatchObject({ id: "text-1", text: "بسم الله" });
  });

  test("teacher action channel rejects unsupported and unconfirmed mutations", async () => {
    await expect(executeTeacherAction("delete_student", {})).resolves.toEqual({ success: false, message: "Unsupported teacher action: delete_student" });
    await expect(executeTeacherAction("reschedule_shift", { shiftId: "shift-1", scope: "single", newStartTime: "2026-07-13T10:00:00Z", newEndTime: "2026-07-13T11:00:00Z" })).resolves.toEqual({ success: false, message: "Please confirm the change explicitly before I update your schedule." });
  });
});
