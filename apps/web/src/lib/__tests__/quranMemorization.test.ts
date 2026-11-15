import assert from "node:assert/strict";
import { test } from "node:test";
import { planDailyLogRepair, readDailyLog, strayDailyLogFields } from "../quranMemorization.ts";

test("readDailyLog reads the nested daily_log map Flutter writes", () => {
  assert.deepEqual(readDailyLog({ daily_log: { "2026-11-14": 3, "2026-11-15": 2 } }), {
    "2026-11-14": 3,
    "2026-11-15": 2,
  });
});

test("readDailyLog adds stray top-level daily_log.<day> fields to the map", () => {
  const data = {
    daily_log: { "2026-11-14": 3, "2026-11-15": 1 },
    "daily_log.2026-11-15": 2,
    "daily_log.2026-11-13": 4,
    memorized: { "1": [1, 2] },
  };
  assert.deepEqual(readDailyLog(data), { "2026-11-13": 4, "2026-11-14": 3, "2026-11-15": 3 });
});

test("readDailyLog tolerates a missing or malformed map", () => {
  assert.deepEqual(readDailyLog({}), {});
  assert.deepEqual(readDailyLog({ daily_log: "nope" }), {});
  assert.deepEqual(readDailyLog({ daily_log: { "2026-11-15": "x" } }), { "2026-11-15": 0 });
});

test("strayDailyLogFields ignores fields that are not a day", () => {
  assert.deepEqual(strayDailyLogFields({ "daily_log.": 1, "daily_log.abc": 2, daily_logs: 3, "daily_log.2026-11-15": 5 }), {
    "2026-11-15": 5,
  });
});

test("planDailyLogRepair is null when there is nothing stray", () => {
  assert.equal(planDailyLogRepair({ daily_log: { "2026-11-15": 2 } }), null);
  assert.equal(planDailyLogRepair({}), null);
});

test("planDailyLogRepair merges stray counts into the map totals and lists fields to delete", () => {
  const plan = planDailyLogRepair({
    daily_log: { "2026-11-14": 3, "2026-11-15": 1 },
    "daily_log.2026-11-15": 2,
    "daily_log.2026-11-13": -1,
  });
  assert.deepEqual(plan, {
    dailyLog: { "2026-11-15": 3, "2026-11-13": -1 },
    strayFields: ["daily_log.2026-11-15", "daily_log.2026-11-13"],
  });
});
