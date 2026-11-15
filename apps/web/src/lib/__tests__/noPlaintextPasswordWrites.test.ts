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

test("no web client code writes temp_password", () => {
  const offenders = sourceFiles(srcRoot).filter((path) => /temp_password/.test(readFileSync(path, "utf8")));
  assert.deepEqual(offenders, []);
});

test("teacher password change only calls Firebase Auth", () => {
  const source = readFileSync(join(srcRoot, "components/TeacherSettingsPage.tsx"), "utf8");
  const body = source.split("\n").find((line) => line.includes("updatePassword(user, next)"));
  assert.ok(body, "password save() not found");
  assert.doesNotMatch(body, /setDoc|updateDoc/);
});
