import test from "node:test";
import assert from "node:assert/strict";
import { describeLogEntry, formatLogDate, parseMonthRecord } from "../finance/monthRecord.ts";

test("a month with no record is open with no history", () => {
  assert.deepEqual(parseMonthRecord(undefined), { status: "open", log: [] });
  assert.deepEqual(parseMonthRecord({}), { status: "open", log: [] });
});

test("reads status and the log, oldest first, from Firestore timestamps", () => {
  const ts = (iso: string) => ({ toDate: () => new Date(iso) });
  const record = parseMonthRecord({
    status: "open",
    log: [
      { action: "reopened", at: ts("2026-10-12T15:00:00Z"), by: "u2", by_name: "Mamadou", reason: "Fix a penalty" },
      { action: "closed", at: ts("2026-10-06T15:00:00Z"), by: "u1", by_name: "Hawa" },
      { action: "mystery", at: ts("2026-10-07T15:00:00Z") },
    ],
  });
  assert.equal(record.status, "open");
  assert.deepEqual(record.log.map((l) => l.action), ["closed", "reopened"]);
  assert.equal(record.log[1].reason, "Fix a penalty");
  assert.equal(record.log[0].reason, "");
  assert.equal(parseMonthRecord({ status: "closed" }).status, "closed");
});

test("log lines read in plain words and say 'you' for the person looking", () => {
  const at = new Date("2026-10-21T15:00:00Z");
  assert.equal(formatLogDate(at), "Oct 21, 2026");
  assert.equal(
    describeLogEntry({ action: "closed", at, by: "u1", by_name: "Hawa Bah", reason: "" }, "2026-09"),
    "Oct 21, 2026 — September closed by Hawa Bah",
  );
  assert.equal(
    describeLogEntry({ action: "closed", at, by: "u1", by_name: "Hawa Bah", reason: "" }, "2026-09", "u1"),
    "Oct 21, 2026 — September closed by you",
  );
  assert.equal(
    describeLogEntry({ action: "reopened", at, by: "u2", by_name: "", reason: "A penalty was wrong" }, "2026-09"),
    "Oct 21, 2026 — September reopened by An administrator: “A penalty was wrong”",
  );
});
