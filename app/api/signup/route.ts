/**
 * Launch-list capture for the CMSN app.
 *
 * Writes to `public.cmsn_signups` in Supabase through PostgREST. The table is
 * insert-only under RLS — anon may INSERT, and there is deliberately no SELECT
 * policy — so the list cannot be read back through the API even with the
 * publishable key in hand. Harvesting it requires the service role, which never
 * reaches this process.
 *
 * Runs server-side so the key is not shipped to the browser, even though a
 * publishable key is designed to tolerate that.
 */

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY;

// Mirrors the cmsn_signups_email_shape check constraint. The database is the
// real gate; this just fails fast and returns a useful message.
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

const MAX_EMAIL_LENGTH = 254;
const MAX_BODY_BYTES = 4096;

function json(body: unknown, status: number) {
  return Response.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
    console.error("signup: SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is not set");
    return json({ error: "Signup is not configured." }, 503);
  }

  const raw = await request.text();
  if (raw.length > MAX_BODY_BYTES) {
    return json({ error: "Request too large." }, 413);
  }

  let payload: unknown;
  try {
    payload = JSON.parse(raw);
  } catch {
    return json({ error: "Expected JSON." }, 400);
  }

  const body = (payload ?? {}) as Record<string, unknown>;

  // Honeypot. A real person never fills a field they cannot see, so a value
  // here means a bot. Answer 200 so it has nothing to tune against.
  if (typeof body.company === "string" && body.company.trim() !== "") {
    return json({ ok: true }, 200);
  }

  const email = typeof body.email === "string" ? body.email.trim() : "";
  if (!email || email.length > MAX_EMAIL_LENGTH || !EMAIL.test(email)) {
    return json({ error: "Enter a valid email address." }, 400);
  }

  const source =
    typeof body.source === "string" && body.source.trim() !== ""
      ? body.source.trim().slice(0, 64)
      : "web";

  let response: Response;
  try {
    response = await fetch(`${SUPABASE_URL}/rest/v1/cmsn_signups`, {
      method: "POST",
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
        authorization: `Bearer ${SUPABASE_PUBLISHABLE_KEY}`,
        "content-type": "application/json",
        // Nothing is echoed back; the table has no SELECT policy to satisfy.
        prefer: "return=minimal",
      },
      body: JSON.stringify({ email, source }),
    });
  } catch (error) {
    console.error("signup: could not reach Supabase", error);
    return json({ error: "Could not reach the server. Try again." }, 502);
  }

  if (response.ok) {
    return json({ ok: true }, 201);
  }

  // 23505 is a unique-violation: already on the list. That is a success from
  // the visitor's side, and answering identically avoids disclosing which
  // addresses are already registered.
  const detail = await response.text();
  if (response.status === 409 || detail.includes("23505")) {
    return json({ ok: true }, 200);
  }

  console.error(`signup: Supabase returned ${response.status}`, detail);
  return json({ error: "Could not save that. Try again." }, 502);
}
