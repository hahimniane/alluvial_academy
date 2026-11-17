import test from "node:test";
import assert from "node:assert/strict";
import { mapUserDoc } from "../adminUsers.ts";
import {
  ZOOM_HOST_ACCOUNTS,
  archiveFields,
  chosenZoomHost,
  decisionActor,
  decisionDocId,
  decisionLabel,
  deleteConfirmed,
  deleteErrorMessage,
  deleteSuccessMessage,
  errorReason,
  fallbackDecisions,
  joinNames,
  mergeDecisions,
  panelActions,
  resetPasswordProblem,
  restoreFields,
  selfGuard,
  switchToast,
  upcomingStudents,
  zoomHostDefaults,
  zoomResultMessage,
  type Decision,
} from "../adminUsersActions.ts";

const ts = (iso: string) => {
  const ms = new Date(iso).getTime();
  return { seconds: Math.floor(ms / 1000), nanoseconds: (ms % 1000) * 1e6, toDate: () => new Date(ms) };
};

const row = (data: Record<string, unknown>, id = "u1") => mapUserDoc(id, data);

test("which actions a person gets", () => {
  const teacher = panelActions(row({ user_type: "teacher" }));
  assert.deepEqual(
    { ...teacher },
    { aiTutor: true, tontine: true, zoom: true, makeAdminTeacher: true, removeAdminAccess: false, archive: true, restore: false, delete: true, studentLogin: false },
  );
  const archivedTeacher = panelActions(row({ user_type: "teacher", is_active: false }));
  assert.equal(archivedTeacher.makeAdminTeacher, false, "no promote on archived teachers (design fix)");
  assert.equal(archivedTeacher.zoom || archivedTeacher.aiTutor || archivedTeacher.tontine, false);
  assert.equal(archivedTeacher.restore, true);
  const adminTeacher = panelActions(row({ user_type: "teacher", is_admin_teacher: true }));
  assert.equal(adminTeacher.makeAdminTeacher, false);
  assert.equal(adminTeacher.removeAdminAccess, true);
  assert.equal(adminTeacher.zoom, true);
  const student = panelActions(row({ user_type: "student" }));
  assert.equal(student.studentLogin, true);
  assert.equal(student.aiTutor, true);
  assert.equal(student.zoom, false);
  assert.equal(panelActions(row({ user_type: "student", is_active: false })).studentLogin, true);
  const parent = panelActions(row({ user_type: "parent" }));
  assert.equal(parent.aiTutor, false);
  assert.equal(parent.tontine, true);
  const admin = panelActions(row({ user_type: "admin" }));
  assert.equal(admin.removeAdminAccess, false, "full admins have no revoke");
  assert.equal(admin.aiTutor, false);
});

test("self guard: no archiving, deleting or demoting yourself", () => {
  const me = row({ user_type: "teacher", is_admin_teacher: true }, "me");
  assert.match(selfGuard(me, "me", "delete") ?? "", /delete your own/);
  assert.match(selfGuard(me, "me", "archive") ?? "", /archive your own/);
  assert.match(selfGuard(me, "me", "removeAdminAccess") ?? "", /own admin access/);
  assert.equal(selfGuard(me, "someone-else", "delete"), null);
  assert.equal(selfGuard(me, "", "delete"), null);
});

test("messages", () => {
  const amina = row({ first_name: "Amina", last_name: "Diallo" });
  assert.equal(switchToast("AI Tutor", true, amina), "AI Tutor turned on for Amina");
  assert.equal(switchToast("Tontine", false, row({ student_code: "x.y", user_type: "student" })), "Tontine turned off for x.y");
  assert.equal(zoomResultMessage("Ibrahima Camara", true, 0), "Zoom turned on for Ibrahima Camara. No upcoming classes needed changing.");
  assert.equal(zoomResultMessage("I C", true, 1), "Zoom turned on for I C. 1 upcoming class updated.");
  assert.equal(zoomResultMessage("I C", false, 12), "Zoom turned off for I C. 12 upcoming classes updated.");
  assert.equal(deleteSuccessMessage("M D", { upcomingClassesDeleted: 2, upcomingClassesUpdated: 1 }, true), "M D was permanently deleted. 2 upcoming classes deleted. Taken off 1 upcoming group class.");
  assert.equal(deleteSuccessMessage("M D", { upcomingClassesDeleted: 0, upcomingClassesUpdated: 0 }, true), "M D was permanently deleted. There were no upcoming classes.");
  assert.equal(deleteSuccessMessage("M D", null, false), "M D was permanently deleted.");
  assert.equal(joinNames(["A"]), "A");
  assert.equal(joinNames(["A", " B "]), "A and B");
  assert.equal(joinNames(["A", "B", "C"]), "A, B and C");
  assert.equal(joinNames([]), "");
});

test("error reasons a person can act on", () => {
  assert.match(errorReason({ code: "permission-denied" }), /permission/);
  assert.match(errorReason({ code: "functions/permission-denied", message: "Only admins" }), /permission/);
  assert.match(errorReason({ code: "unavailable" }), /offline/);
  assert.match(errorReason(new Error("Failed to fetch")), /offline/);
  assert.match(errorReason({ code: "unauthenticated" }), /sign in again/);
  assert.equal(errorReason({ code: "functions/failed-precondition", message: "Zoom can only be enabled for teachers" }), "Zoom can only be enabled for teachers");
  assert.match(errorReason({ code: "functions/internal", message: "internal" }), /something went wrong/);
  assert.equal(deleteErrorMessage({ message: "You cannot delete your own account" }, "X"), "You can't delete your own account.");
  assert.equal(deleteErrorMessage({ message: "User must be deactivated (archived) before deletion" }, "X"), "X must be archived before they can be deleted.");
  assert.equal(deleteErrorMessage({ code: "unavailable", archivedFirst: true }, "X"), "X could not be deleted: you appear to be offline, try again when connected. They are archived now; you can restore them.");
});

test("reset password validation mirrors the server", () => {
  assert.equal(resetPasswordProblem(""), null);
  assert.equal(resetPasswordProblem("abcdef"), null);
  assert.match(resetPasswordProblem("abc") ?? "", /at least 6/);
  assert.match(resetPasswordProblem(" abcdef") ?? "", /spaces/);
  assert.match(resetPasswordProblem("abcdef ") ?? "", /spaces/);
  assert.match(resetPasswordProblem("      ") ?? "", /only spaces/);
  assert.match(resetPasswordProblem("a".repeat(129)) ?? "", /128/);
  assert.equal(resetPasswordProblem("a".repeat(128)), null);
});

test("delete needs the word DELETE", () => {
  assert.equal(deleteConfirmed("DELETE"), true);
  assert.equal(deleteConfirmed(" DELETE "), true);
  assert.equal(deleteConfirmed("delete"), false);
  assert.equal(deleteConfirmed(""), false);
});

test("zoom host: the teacher's current host is pre-selected; typed host wins", () => {
  assert.deepEqual(zoomHostDefaults(""), { selected: ZOOM_HOST_ACCOUNTS[0], custom: "" });
  assert.deepEqual(zoomHostDefaults("Billing@alluwaleducationhub.org"), { selected: ZOOM_HOST_ACCOUNTS[1], custom: "" });
  assert.deepEqual(zoomHostDefaults("lane3@x.org"), { selected: "", custom: "lane3@x.org" });
  assert.equal(chosenZoomHost(ZOOM_HOST_ACCOUNTS[0], "  "), ZOOM_HOST_ACCOUNTS[0]);
  assert.equal(chosenZoomHost(ZOOM_HOST_ACCOUNTS[0], " other@x.org "), "other@x.org");
});

test("zoom scope: students of upcoming teaching classes only", () => {
  const now = new Date("2026-11-17T12:00:00Z");
  const later = new Date("2026-11-20T12:00:00Z");
  const earlier = new Date("2026-11-10T12:00:00Z");
  const list = upcomingStudents(
    [
      { studentIds: ["s1", "s2"], studentNames: ["Binta", ""], category: "teaching", start: later },
      { studentIds: ["s3"], studentNames: ["Past"], category: "teaching", start: earlier },
      { studentIds: ["s4"], studentNames: ["Lead"], category: "leadership", start: later },
      { studentIds: ["s2"], studentNames: ["Alpha"], category: "Teaching", start: later },
      { studentIds: [" "], studentNames: [""], category: "teaching", start: later },
    ],
    now,
  );
  assert.deepEqual(list, [
    { id: "s2", name: "Alpha" },
    { id: "s1", name: "Binta" },
  ]);
});

test("archive / restore field sets", () => {
  const v = { uid: "adm", email: " Admin@School.org " };
  assert.deepEqual(archiveFields(v, "NOW"), { is_active: false, deactivated_at: "NOW", deactivated_by_uid: "adm", deactivated_by_email: "admin@school.org", updated_at: "NOW" });
  assert.deepEqual(restoreFields(v, "NOW", "DEL"), {
    is_active: true,
    activated_at: "NOW",
    activated_by_uid: "adm",
    activated_by_email: "admin@school.org",
    updated_at: "NOW",
    deactivated_at: "DEL",
    deactivated_by_uid: "DEL",
    deactivated_by_email: "DEL",
  });
});

test("recent decisions: recorded events plus the user doc's own fallbacks", () => {
  const r = row({
    created_by_uid: "adm",
    date_added: ts("2026-09-01T10:00:00Z"),
    deactivated_by_uid: "adm2",
    deactivated_at: ts("2026-10-01T10:00:00Z"),
    activated_by_uid: "adm",
    activated_at: "2026-10-05T10:00:00Z",
  });
  const fallbacks = fallbackDecisions(r);
  assert.deepEqual(fallbacks.map((f) => f.action), ["user.created", "user.archived", "user.restored"]);
  const recorded: Decision[] = [{ id: "e1", action: "user.archived", actorUid: "adm2", actorName: "Sekou", at: new Date("2026-10-01T10:00:01Z"), legacy: false }];
  const merged = mergeDecisions(recorded, fallbacks, 5);
  assert.deepEqual(merged.map((d) => d.action), ["user.restored", "user.archived", "user.created"]);
  assert.equal(merged[1].legacy, false, "the recorded archive wins over the fallback");
  assert.equal(mergeDecisions(recorded, fallbacks, 2).length, 2);
  assert.equal(decisionLabel("user.role_changed"), "Changed user role");
  assert.equal(decisionLabel("user.something_new"), "Something new");
  assert.equal(decisionDocId("user", "a/b"), "user__a_b");
  assert.equal(decisionActor("Sekou Conde", "uid"), "Sekou Conde");
  assert.equal(decisionActor("x@y.org", "uid"), "");
  assert.equal(decisionActor("+1 646 555 0110", "uid"), "");
  assert.equal(decisionActor("", "service@proj.iam.gserviceaccount.com"), "System");
  assert.equal(decisionActor("Anyone", "u", "system"), "System");
});
