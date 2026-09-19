"use client";

import { useState } from "react";

type Status = "idle" | "sending" | "done" | "error";

export default function SignupForm({ source = "web" }: { source?: string }) {
  const [email, setEmail] = useState("");
  const [company, setCompany] = useState(""); // honeypot
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (status === "sending") return;

    setStatus("sending");
    setMessage("");

    try {
      const response = await fetch("/api/signup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, company, source }),
      });
      const data = await response.json().catch(() => ({}));

      if (response.ok) {
        setStatus("done");
        setEmail("");
      } else {
        setStatus("error");
        setMessage(data?.error ?? "Could not save that. Try again.");
      }
    } catch {
      setStatus("error");
      setMessage("Could not reach the server. Try again.");
    }
  }

  if (status === "done") {
    return (
      <p
        role="status"
        className="text-sm tracking-[0.18em] uppercase text-[var(--cmsn-off-white)]"
      >
        You&rsquo;re on the list. We&rsquo;ll send the first invite.
      </p>
    );
  }

  return (
    <form onSubmit={onSubmit} className="w-full max-w-md" noValidate>
      <div className="flex flex-col gap-3 sm:flex-row">
        <label htmlFor="email" className="sr-only">
          Email address
        </label>
        <input
          id="email"
          type="email"
          name="email"
          required
          autoComplete="email"
          placeholder="Email address"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          aria-invalid={status === "error"}
          aria-describedby={status === "error" ? "signup-error" : undefined}
          className="min-w-0 flex-1 border border-white/25 bg-transparent px-4 py-3
                     text-[15px] text-[var(--cmsn-off-white)] placeholder:text-white/35
                     outline-none transition-colors focus:border-[var(--cmsn-off-white)]"
        />

        {/* Not shown to people. A filled value marks the sender as a bot. */}
        <input
          type="text"
          name="company"
          tabIndex={-1}
          autoComplete="off"
          aria-hidden="true"
          value={company}
          onChange={(event) => setCompany(event.target.value)}
          className="absolute h-0 w-0 overflow-hidden opacity-0"
        />

        <button
          type="submit"
          disabled={status === "sending"}
          className="shrink-0 bg-[var(--cmsn-off-white)] px-7 py-3 text-[11px]
                     font-medium uppercase tracking-[0.22em] text-[var(--cmsn-off-black)]
                     transition-opacity hover:opacity-85 disabled:opacity-50"
        >
          {status === "sending" ? "Sending" : "Request invite"}
        </button>
      </div>

      {status === "error" && (
        <p id="signup-error" role="alert" className="mt-3 text-sm text-white/60">
          {message}
        </p>
      )}
    </form>
  );
}
