import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

// users/{uid} is readable by every signed-in user, so a password written there
// is readable by every parent, student and teacher. Self-service password
// changes must only touch Firebase Auth.
const srcRoot = fileURLToPath(new URL("../../", import.meta.url));

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (name === "__tests__" || name === "node_modules") return [];
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return /\.(ts|tsx)$/.test(name) ? [path] : [];
  });
}

// Student passwords live in student_credentials/{uid}, written only by Cloud
// Functions. The one web file allowed to name the legacy user-doc field reads
// it as a fallback and never writes anything.
const READER = join(srcRoot, "lib/studentCredentials.ts");

test("only the credential reader names temp_password", () => {
  const offenders = sourceFiles(srcRoot).filter((path) => /temp_password/.test(readFileSync(path, "utf8")));
  assert.deepEqual(offenders, [READER]);
});

test("the credential reader never writes", () => {
  const source = readFileSync(READER, "utf8");
  assert.doesNotMatch(source, /\b(setDoc|updateDoc|addDoc|deleteDoc|writeBatch|runTransaction)\b/);
});

test("no web code writes the credential store", () => {
  const writers = sourceFiles(srcRoot).filter((path) => {
    const source = readFileSync(path, "utf8");
    return /student_credentials/.test(source) && /\b(setDoc|updateDoc|addDoc|deleteDoc|writeBatch)\b/.test(source);
  });
  assert.deepEqual(writers, []);
});

test("teacher password change only calls Firebase Auth", () => {
  const source = readFileSync(join(srcRoot, "components/TeacherSettingsPage.tsx"), "utf8");
  const body = source.split("\n").find((line) => line.includes("updatePassword(user, next)"));
  assert.ok(body, "password save() not found");
  assert.doesNotMatch(body, /setDoc|updateDoc/);
});
