import test from "node:test";
import assert from "node:assert/strict";
import { FAMILY_CLASS_TYPE, groupApplicants, groupIds, listNames } from "../familyGroups.ts";
import { blockById, slotsFor } from "../enrollmentDomain.ts";

const a = (over: Partial<Parameters<typeof groupApplicants>[0][number]> = {}) => ({
  id: "e1", parentLinkId: "link-1", classType: FAMILY_CLASS_TYPE, subject: "Adlam", studentName: "test 1", ...over,
});

test("children of one family class become a single application", () => {
  const groups = groupApplicants([a({ id: "e1", studentName: "test 1" }), a({ id: "e2", studentName: "test 2" })]);
  assert.equal(groups.length, 1);
  assert.equal(groups[0].isFamilyClass, true);
  assert.deepEqual(groups[0].studentNames, ["test 1", "test 2"]);
  assert.deepEqual(groupIds(groups[0]), ["e1", "e2"]);
  assert.equal(groups[0].primary.id, "e1");
});

test("the same family in different programs stays separate — they are different classes", () => {
  const groups = groupApplicants([
    a({ id: "e1", subject: "Adlam" }),
    a({ id: "e2", subject: "Adlam", studentName: "test 2" }),
    a({ id: "e3", subject: "Religious Studies" }),
    a({ id: "e4", subject: "Religious Studies", studentName: "test 2" }),
  ]);
  assert.equal(groups.length, 2);
  assert.deepEqual(groups.map((g) => g.members.length), [2, 2]);
  assert.deepEqual(groups.map((g) => g.primary.subject), ["Adlam", "Religious Studies"]);
});

test("only an exclusive family class groups", () => {
  for (const classType of ["One-on-One", "With Other Students", "Group", ""]) {
    const groups = groupApplicants([a({ id: "e1", classType }), a({ id: "e2", classType, studentName: "test 2" })]);
    assert.equal(groups.length, 2, `${classType || "(empty)"} must not group`);
    assert.equal(groups[0].isFamilyClass, false);
  }
});

test("siblings from different submissions never merge", () => {
  const groups = groupApplicants([a({ id: "e1", parentLinkId: "link-1" }), a({ id: "e2", parentLinkId: "link-2" })]);
  assert.equal(groups.length, 2);
});

test("a family class with no link id is left alone rather than merged by name", () => {
  const groups = groupApplicants([a({ id: "e1", parentLinkId: "" }), a({ id: "e2", parentLinkId: "", studentName: "test 2" })]);
  assert.equal(groups.length, 2);
});

test("one child in a family class is just a class", () => {
  const [group] = groupApplicants([a()]);
  assert.equal(group.isFamilyClass, false);
  assert.equal(group.members.length, 1);
});

test("group order follows the order the list was already in", () => {
  const groups = groupApplicants([
    a({ id: "solo", classType: "One-on-One", studentName: "Zara" }),
    a({ id: "e1", studentName: "test 1" }),
    a({ id: "e2", studentName: "test 2" }),
  ]);
  assert.deepEqual(groups.map((g) => g.primary.id), ["solo", "e1"]);
});

test("subject matching ignores case and padding", () => {
  const groups = groupApplicants([a({ id: "e1", subject: "Adlam" }), a({ id: "e2", subject: " adlam " })]);
  assert.equal(groups.length, 1);
});

test("names read as a sentence", () => {
  assert.equal(listNames(["test 1"]), "test 1");
  assert.equal(listNames(["a", "b"]), "a and b");
  assert.equal(listNames(["a", "b", "c"]), "a, b and c");
  assert.equal(listNames([" ", ""]), "");
});

test("the broadcast dialog starts from the family's window, not an empty list", () => {
  // Regression: the new enrollment form collects a part of the day, never
  // exact hours, so the dialog opened with no slots and refused to broadcast.
  const afternoon = blockById("Afternoon")!;
  const offered = slotsFor(afternoon, 60, 30);
  assert.equal(offered.length, 7, "an afternoon of one-hour classes offers seven windows");
  assert.equal(offered[0], "12:00 PM - 1:00 PM");
  assert.equal(offered[offered.length - 1], "3:00 PM - 4:00 PM");
  assert.deepEqual(slotsFor(blockById(""), 60, 30), [], "no window means nothing to prefill");
});
