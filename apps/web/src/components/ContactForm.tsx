"use client";

import { FormEvent, useState } from "react";
import { submitContactMessage } from "@/lib/forms";

export function ContactForm() {
  const [status, setStatus] = useState<"idle" | "saving" | "success" | "error">("idle");

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    setStatus("saving");
    try {
      await submitContactMessage({
        name: String(form.get("name") ?? ""),
        email: String(form.get("email") ?? ""),
        message: String(form.get("message") ?? ""),
      });
      formElement.reset();
      setStatus("success");
    } catch {
      setStatus("error");
    }
  }

  return (
    <form
      onSubmit={onSubmit}
      className="grid gap-6 rounded-[24px] border border-slate-100 bg-white p-6 shadow-[0_10px_30px_rgba(15,23,42,0.05)] sm:p-10"
    >
      <h2 className="text-2xl font-bold text-[#111827]">Send Message</h2>
      <label className="grid gap-2 text-sm font-semibold text-[#374151]">
        Name
        <input
          name="name"
          className="min-h-12 rounded-xl border-0 bg-[#F9FAFB] px-4 text-base text-[#111827] outline outline-1 outline-slate-200 transition placeholder:text-[#9CA3AF] focus:outline-2 focus:outline-[#3B82F6]"
          required
          placeholder="Your full name"
          autoComplete="name"
        />
      </label>
      <label className="grid gap-2 text-sm font-semibold text-[#374151]">
        Email
        <input
          name="email"
          className="min-h-12 rounded-xl border-0 bg-[#F9FAFB] px-4 text-base text-[#111827] outline outline-1 outline-slate-200 transition placeholder:text-[#9CA3AF] focus:outline-2 focus:outline-[#3B82F6]"
          required
          type="email"
          placeholder="you@example.com"
          autoComplete="email"
        />
      </label>
      <label className="grid gap-2 text-sm font-semibold text-[#374151]">
        Message
        <textarea
          name="message"
          className="min-h-[120px] resize-y rounded-xl border-0 bg-[#F9FAFB] px-4 py-4 text-base text-[#111827] outline outline-1 outline-slate-200 transition placeholder:text-[#9CA3AF] focus:outline-2 focus:outline-[#3B82F6]"
          required
          placeholder="How can we help you?"
        />
      </label>
      <button
        type="submit"
        className="inline-flex min-h-14 w-full items-center justify-center rounded-2xl bg-[#3B82F6] px-5 text-base font-semibold text-white transition hover:bg-[#2563EB] disabled:cursor-wait disabled:opacity-75"
        disabled={status === "saving"}
      >
        {status === "saving" ? "Sending..." : "Send Message"}
      </button>
      {status === "success" ? <p className="text-sm font-bold text-emerald-700">Message sent successfully. We will contact you soon.</p> : null}
      {status === "error" ? <p className="text-sm font-bold text-red-700">We could not send the message. Please try again.</p> : null}
    </form>
  );
}
