import test from "node:test";
import assert from "node:assert/strict";
import {
  DRAFT_COLUMNS,
  STUDENT_COLUMNS,
  TEACHER_COLUMNS,
  draftRow,
  exportDate,
  studentRow,
  studentSheet,
  teacherRow,
  type ExportApplicant,
} from "../applicantExport.ts";
import { columnName, escapeXml, safeSheetName, workbookParts, zipParts } from "../xlsx.ts";
import { fromDateInput } from "../studentDiscount.ts";

const applicant = (over: Partial<ExportApplicant> = {}): ExportApplicant => ({
  id: "e1",
  status: "matched",
  submittedAt: new Date("2026-08-01T09:30:00Z"),
  studentName: "Amina Diallo",
  age: "10",
  gender: "Female",
  isAdult: false,
  gradeLevel: "Beginner",
  programTitle: "Religious Studies",
  classType: "One-on-One",
  sessionDuration: "1 hour",
  hoursPerWeek: 2,
  sessionsPerWeek: 2,
  days: ["Mon", "Wed"],
  block: "Evening",
  timeZone: "America/New_York",
  preferredLanguage: "Pular",
  schedulingNotes: "Not before 5pm",
  parentName: "Fatou Diallo",
  email: "f@example.com",
  phone: "555",
  whatsApp: "555",
  city: "Bronx",
  country: "USA",
  teacherName: "Mariama Bah",
  teacherTimeZone: "Africa/Conakry",
  matchedAt: new Date("2026-08-20T00:00:00Z"),
  studentUserId: "u1",
  parentLinked: true,
  discount: null,
  ...over,
});

const at = (row: unknown[], name: string) => row[STUDENT_COLUMNS.indexOf(name as never)];

test("every column layout has a matching row width", () => {
  assert.equal(studentRow(applicant(), true).length, STUDENT_COLUMNS.length);
  assert.equal(
    draftRow({
      id: "d1", updatedAt: null, step: 3, stepTitle: "Programs", role: "Parent",
      studentNames: ["A"], subjects: ["B"], parentName: "P", email: "e", phone: "p",
      whatsApp: "w", city: "c", timeZone: "t",
    }).length,
    DRAFT_COLUMNS.length,
  );
  assert.equal(
    teacherRow({
      id: "t1", fullName: "T", email: "e", phoneNumber: "p", currentLocation: "l", gender: "g",
      nationality: "n", currentStatus: "s", teachingPrograms: [], englishSubjects: [], languages: [],
      timeDiscipline: "", scheduleBalance: "", tajwidLevel: "", quranMemorization: "",
      arabicProficiency: "", interestReason: "", electricityAccess: "", teachingComfort: "",
      availabilityStart: "", teachingDevice: "", internetAccess: "", status: "Pending", submittedAt: null,
    }).length,
    TEACHER_COLUMNS.length,
  );
});

test("no column name is repeated", () => {
  for (const columns of [STUDENT_COLUMNS, DRAFT_COLUMNS, TEACHER_COLUMNS]) {
    assert.equal(new Set(columns).size, columns.length);
  }
});

test("the setup columns report what the strip reports", () => {
  const pending = studentRow(applicant({ studentUserId: "", parentLinked: false }), false);
  assert.equal(at(pending, "Account Created"), "No");
  assert.equal(at(pending, "Schedule Finalized"), "No");
  assert.equal(at(pending, "Parent Account"), "No");

  const ready = studentRow(applicant(), true);
  assert.equal(at(ready, "Account Created"), "Yes");
  assert.equal(at(ready, "Schedule Finalized"), "Yes");
  assert.equal(at(ready, "Parent Account"), "Yes");
});

test("a schedule without an account exports as No, matching the screen", () => {
  assert.equal(at(studentRow(applicant({ studentUserId: "" }), true), "Schedule Finalized"), "No");
});

test("discount columns are blank when there is no discount", () => {
  const row = studentRow(applicant(), true);
  for (const column of ["Discount Type", "Discount Value", "Discount Duration", "Discount Reason", "Discount Note"]) {
    const value = at(row, column);
    assert.ok(value === "" || value === null, `${column} should be blank, got ${String(value)}`);
  }
});

test("discount columns spell out the discount when there is one", () => {
  const row = studentRow(
    applicant({
      discount: {
        mode: "percent", value: 20, duration: "months", months: 3,
        startDate: fromDateInput("2026-08-15"), reason: "Sibling discount", note: "Approved",
      },
    }),
    true,
  );
  assert.equal(at(row, "Discount Type"), "Percentage");
  assert.equal(at(row, "Discount Value"), 20);
  assert.equal(at(row, "Discount Duration"), "3 months");
  assert.equal(at(row, "Discount Starts"), "Aug 15, 2026");
  assert.equal(at(row, "Discount Reason"), "Sibling discount");
  assert.equal(at(row, "Enrollment Start"), "Aug 15, 2026");
});

test("the requested window is spelled out, not left as a bare id", () => {
  assert.equal(at(studentRow(applicant(), true), "Requested Window"), "Evening (4:00 PM – 8:59 PM)");
  assert.equal(at(studentRow(applicant({ block: "" }), true), "Requested Window"), "");
});

test("dates export sortable rather than locale-dependent", () => {
  assert.equal(exportDate(new Date("2026-08-01T09:30:00Z")), "2026-08-01 09:30");
  assert.equal(exportDate(null), "");
});

test("counts and hours stay numeric so a spreadsheet can total them", () => {
  const row = studentRow(applicant(), true);
  assert.equal(typeof at(row, "Hours / Week"), "number");
  assert.equal(typeof at(row, "Sessions / Week"), "number");
  assert.equal(at(studentRow(applicant({ hoursPerWeek: null }), true), "Hours / Week"), null);
});

/* ------------------------------------------------------------------ xlsx -- */

test("xml escaping covers the characters that break a workbook", () => {
  assert.equal(escapeXml('a & b < c > d " e \' f'), "a &amp; b &lt; c &gt; d &quot; e &apos; f");
  // Control characters are illegal in XML 1.0 and make Excel reject the file.
  const dirty = `clean${String.fromCharCode(0)}text${String.fromCharCode(31)}here`;
  assert.equal(escapeXml(dirty), "cleantexthere");
  // Tab, newline and carriage return are legal and must survive.
  assert.equal(escapeXml("a\tb\nc\rd"), "a\tb\nc\rd");
});

test("column names run past Z", () => {
  assert.equal(columnName(0), "A");
  assert.equal(columnName(25), "Z");
  assert.equal(columnName(26), "AA");
  // The student sheet has 37 columns, so it needs two-letter names.
  assert.equal(columnName(STUDENT_COLUMNS.length - 1), "AK");
});

test("sheet names are made legal for Excel", () => {
  assert.equal(safeSheetName("Reports: 2026/Q3 [draft]"), "Reports  2026 Q3  draft");
  assert.equal(safeSheetName(""), "Sheet");
  assert.ok(safeSheetName("x".repeat(50)).length <= 31);
});

test("duplicate sheet names are made unique, since a clash breaks the file", () => {
  const parts = workbookParts([
    { name: "Data", headers: ["a"], rows: [] },
    { name: "Data", headers: ["a"], rows: [] },
  ]);
  const workbook = parts.find((p) => p.name === "xl/workbook.xml")!.content;
  assert.ok(workbook.includes('name="Data"'));
  assert.ok(workbook.includes('name="Data 2"'));
});

test("the workbook carries a frozen header, an auto filter and sized columns", () => {
  const parts = workbookParts([studentSheet([applicant()], new Set(["u1"]))]);
  const sheet = parts.find((p) => p.name === "xl/worksheets/sheet1.xml")!.content;
  assert.match(sheet, /<pane ySplit="1" topLeftCell="A2".*state="frozen"\/>/);
  assert.match(sheet, /<autoFilter ref="A1:AK2"\/>/);
  assert.match(sheet, /<col min="1" max="1" width="\d+"/);
});

test("the zip has the signatures a reader looks for", () => {
  const bytes = zipParts([{ name: "a.txt", content: "hello" }]);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  assert.equal(view.getUint32(0, true), 0x04034b50, "local file header");
  // End-of-central-directory is the last 22 bytes when there is no comment.
  assert.equal(view.getUint32(bytes.length - 22, true), 0x06054b50, "end of central directory");
  assert.equal(view.getUint16(bytes.length - 22 + 10, true), 1, "one entry");
});
