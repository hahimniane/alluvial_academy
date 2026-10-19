import test from "node:test";
import assert from "node:assert/strict";
import { nameScore, rankStudentMatches, type StudentCandidate } from "../existingStudentMatch.ts";

const student = (id: string, displayName: string, studentCode = ""): StudentCandidate => ({ id, displayName, studentCode });

test("an exact name ranks first", () => {
  assert.equal(nameScore("Mansour Bah", "Mansour Bah"), 100);
  assert.equal(nameScore("saidou  souaré", "Saidou Souare"), 100);
});

test("one typo in a name part still matches", () => {
  assert.equal(nameScore("Ibrahima Dialo", "Ibrahima Diallo"), 90);
});

test("a different first name never matches, even with the same family name", () => {
  assert.equal(nameScore("Amadou Barry", "Mamadou Aliou Barry"), 0);
  assert.equal(nameScore("Boubacar Diallo", "Mariama Diallo"), 0);
});

test("a first name alone matches weakly", () => {
  assert.equal(nameScore("Isa", "Isa Jallow"), 40);
});

test("ranking keeps only matching accounts, best first", () => {
  const students = [
    student("a", "Amadou Diallo"),
    student("b", "Amadou Barry"),
    student("c", "Mamadou Aliou Barry"),
    student("d", "Amadou Barry Sow"),
  ];
  assert.deepEqual(rankStudentMatches("Amadou Barry", students).map((s) => s.id), ["b", "d"]);
});

test("a typed search finds accounts by name or student code", () => {
  const students = [student("a", "Rahmatoulaye Bah", "rahmatoulaye.bah"), student("b", "Ismail Bah", "ismail.bah")];
  assert.deepEqual(rankStudentMatches("Rahmatoulaye Bah", students, "ism").map((s) => s.id), ["b"]);
  assert.deepEqual(rankStudentMatches("Rahmatoulaye Bah", students, "rahmatoulaye.b").map((s) => s.id), ["a"]);
});
