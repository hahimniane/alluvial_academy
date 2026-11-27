"use client";

/**
 * The two callables behind form links. Both work without an account; the
 * server decides what a form link may show and accept.
 */
import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import type { PublicFormInfo } from "@/lib/publicForms";

export async function fetchPublicForm(id: string): Promise<PublicFormInfo> {
  const result = await httpsCallable<{ id: string }, PublicFormInfo>(functions, "getPublicForm")({ id });
  return result.data;
}

export async function sendPublicFormResponse(input: { id: string; name: string; phone: string; responses: Record<string, unknown> }) {
  const result = await httpsCallable<typeof input, { success: boolean; id: string }>(functions, "submitPublicFormResponse")(input);
  return result.data;
}
