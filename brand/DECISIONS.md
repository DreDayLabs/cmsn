# DECISIONS — CMSN

The register. This is the **only** document that changes a decision's status.
Where any other document in `brand/` conflicts with an entry here, this file wins
and the other document is stale.

Status: 🔒 LOCKED · 🟡 PROPOSED · ⚙️ PRODUCTION DIRECTION (executable, not founder-locked) · ⚠️ SHIPPED-UNRATIFIED · 📦 ARCHIVED

IDs are prefixed `C-` and are CMSN's own. They are **not** the same series as
Moris Hill's `D-` register; the two houses are separate (`brand/08-app-strategy.md`,
and Moris Hill D-008).

This register was created on 2026-09-19. Decisions made before that date live in
the numbered `brand/` documents and in `guidelines/IDENTITY-AUTHORITY.md`; they
are not restated here unless something has changed.

---

## Go-to-market · 2026-09-19

Founder decision, recorded from founder direction on 2026-09-19.

### C-001 · Collection 01 is sold by pre-order. Nothing is bought into stock
🔒 **LOCKED** — founder

Orders are taken first. Production runs against confirmed demand. No inventory
is purchased ahead of it.

A **sample run is not a production run**: a small set of pieces made once to be
photographed and to carry the pre-order. No size grade, no minimum order
quantity, no unsold stock. Budget it as a shoot cost, not a collection cost.

**This supersedes the inventory-first plan in `04-product-and-manufacturing.md`.**
That document's launch timeline is worked back from "inventory lands; self-fulfil
run 1," and it quotes tier-2 minimums of 300+ per style. Followed as written it
buys stock before demand exists, which is exactly what this decision forbids.
Its sourcing research, size-run work and tech-pack sequencing remain useful. Its
purchasing model does not.

Rationale, recorded so it survives a launch week: unsold inventory is the most
commonly cited cause of independent DTC failure across the 2024–25 closures, and
capital is not a defence — Parade raised over $40M, reached roughly $10M revenue,
and shut down in 2025. Around 38% of small fashion brands now run pre-order as a
demand-validation channel. {The closure reporting is trade press; the percentage
comes from secondary sources citing McKinsey, so treat it as directional.}

The launch list that feeds this is live: `public.cmsn_signups`, captured by
`/api/signup`, insert-only under RLS.

### C-002 · Activations are CMSN's lane. The run club comes first
🔒 **LOCKED** — founder (the lane) · ⚙️ **PRODUCTION DIRECTION** (run club first)

Physical activations belong to CMSN: group runs, yoga, spin, training-led
events. Moris Hill takes none of them (Moris Hill D-022) — the split expresses
the two houses rather than dividing work. **CMSN is participatory**: you show
up, you earn it, the app keeps score.

**Sequence the lane by cost.** A run club needs a meeting point and someone to
show up. Yoga and spin need a studio and an instructor every time, whether eight
people come or forty. Start with the run, on these grounds:

- **It recurs.** Same time, same place, weekly. A class is an event; a run club
  is a habit, and habit is what a scoring app runs on.
- **It closes the loop with the app.** Run, log it, get a Score. Participation
  plus a ranking we own, rather than one we rent.
- **It generates the photography we do not have.** Real people doing the thing,
  in what they already own. No stock, no models, no invented product.

That last point is why the lanes differ at all: CMSN can make content out of
people showing up in their own clothes. Moris Hill cannot, because there the
garment *is* the content — which is what its sample run exists to solve.

This is additive to `05-content-and-community.md`, not a replacement. The Walk,
The Work and The Word stand; the run club is where they get filmed with other
people in frame.

---

## Open

| ID | Question | Gate |
| --- | --- | --- |
| C-003 | Which activation follows the run club, and whether any of it is paid | After the run club has a repeating turnout |
| C-004 | Pre-order window length, deposit vs full payment, and the refund position | Before the first pre-order opens |
| C-005 | Commerce platform and checkout | Before the first pre-order opens |
| C-006 | CMSN brand typeface — never chosen; the site runs a Helvetica stack as an explicit placeholder | Before any printed collateral |

---

## History

2026-09-14: Identity Revision 02 founder-approved. See `guidelines/IDENTITY-AUTHORITY.md`.
2026-09-19: Revision 02 wired to every surface and merged to main; superseded marks removed. Site rebuilt as an app landing page with launch-list capture. This register created; C-001 and C-002 recorded.
