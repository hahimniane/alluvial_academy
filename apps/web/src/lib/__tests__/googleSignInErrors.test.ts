import test from "node:test";
import assert from "node:assert/strict";
import { googleErrorText } from "../googleSignInErrors.ts";

const err = (code: string) => Object.assign(new Error(code), { code });

test("closing the Google window shows nothing", () => {
  assert.equal(googleErrorText(err("auth/popup-closed-by-user")), null);
  assert.equal(googleErrorText(err("auth/cancelled-popup-request")), null);
});

test("unregistered and archived accounts get their own message", () => {
  assert.match(googleErrorText(err("user-not-registered")) ?? "", /No account found/);
  assert.match(googleErrorText(err("user-deactivated")) ?? "", /archived/);
});

test("a blocked popup is explained; anything else is a generic failure", () => {
  assert.match(googleErrorText(err("auth/popup-blocked")) ?? "", /pop-ups/);
  assert.equal(googleErrorText(new Error("boom")), "Google sign-in failed. Please try again.");
});
