# CMSN — App & Ecosystem Strategy

> This file documents the product and business strategy for the CMSN iOS
> app (built at `../ios/CMSNApp/`) and its role in the CMSN ecosystem. It
> follows the same discipline as [01-brand-strategy.md](01-brand-strategy.md):
> confidence levels stated, sources cited where they exist, and every
> number treated as a hypothesis to test against real users, not a
> guarantee.

## 1. Product thesis

CMSN is not shipping a fitness tracker that happens to match the brand.
It's building a **connected performance ecosystem** that participates in
the user's day from preparation through recovery — apparel, accessories,
training programs, content, and events are physical expressions of one
underlying system, and the app is that system's record of truth.

The loop: **Dress → Prepare → Perform → Prove → Recover → Return.**

- **Dress** — what the athlete wears, and the only loop stage that's
  primarily physical, not software. The app's job here is small and
  optional: capture how the gear performed.
- **Prepare** — what am I training today, what equipment do I have, how do
  I feel, what did I do last time.
- **Perform** — the session itself: exercise, sets, reps, weight, rest,
  substitutions, discomfort.
- **Prove** — what actually happened, honestly, including partial work.
- **Recover** — sleep, soreness, hydration, protein, rest-day adherence.
- **Return** — what happens after a gap, so a missed week never costs the
  athlete their identity or their progress history.

The strategic objective is to **own more moments across the training day**,
not to accumulate more features. A brand that only shows up on drop day
has no reason to be opened the other 359 days of the year — the app is
that reason. This directly answers the failure pattern this playbook
already identified in incumbents and challengers alike
([01-brand-strategy.md](01-brand-strategy.md)): community and product
depth get cut under pressure, and a daily-touch surface is exactly the
kind of depth that's expensive to fake and easy to defend.

## 2. Audience positioning

The app is built for an **intentionally balanced audience** — roughly
51% male-oriented, 49% female-oriented — even though the apparel line
itself is sequenced men's-first for good, product-specific reasons (the
big-and-tall fit-block moat described in
[04-product-and-manufacturing.md](04-product-and-manufacturing.md)).
Software carries none of the manufacturing/MOQ constraints that justified
sequencing the clothing, so there's no reason to replicate that sequencing
in the app's design. Concretely:

- No gender-exclusive product architecture. No "women's version" of the
  core training system, no assumption that men only lift and women only do
  cardio.
- The training profile, onboarding flow, and every data model in the V0
  build are one shape for every user — see `ios/CMSNApp/CMSNApp/Models/Athlete.swift`
  and `TrainingEnums.swift`, which contain zero gendered branching.
- Design hypotheses, not fixed rules, about behavioral tendencies: men may
  weight objective scorekeeping (weight lifted, e1RM, PRs, challenges) more
  heavily; women may respond more strongly to program guidance, variety,
  social participation, and external encouragement *(medium confidence —
  JMIR Human Factors research on fitness-app engagement patterns by
  gender; directional, not a hard behavioral law, and CMSN should treat it
  as something to A/B test once there's usage data, not something to
  design around blindly)*.

### Four female relationships to the brand

The app and the broader ecosystem should intentionally support:

1. **Athlete** — strength training, cardio, mobility, yoga, dance,
   cycling, kettlebells, recovery — all first-class training styles in the
   app's taxonomy (`TrainingStyle` enum), not an afterthought bolted onto a
   men's programming engine.
2. **Consumer** — buys and wears CMSN apparel because it meets performance
   and aesthetic standards on its own terms.
3. **Influencer** — shapes whether CMSN reads as desirable on the men in
   her life. CMSN menswear should create the emotional response premium
   tailoring creates: the wearer looks composed, intentional, capable.
4. **Gift buyer** — purchases CMSN for boyfriends, husbands, fathers,
   brothers, sons, colleagues. This has direct commerce implications (§11).

## 3. Brand positioning (app + ecosystem)

CMSN is not "athletic apparel with an app." It sits between: premium
athletic performance, personal discipline, modern masculine presentation,
female-led desirability, everyday wellness, training intelligence, and
giftable luxury. The relevant lesson from luxury menswear isn't visual
(CMSN isn't imitating a tailoring brand's look) — it's emotional
positioning: women should want the men around them wearing CMSN because it
signals care, intention, discipline, and taste; men should want to wear it
because it helps them train and identify with visible progress; and women
should want CMSN *for themselves*, on its own terms, not as an accessory
to the men's line.

## 4. Dual-user design

The app deliberately serves two behavioral extremes rather than optimizing
for an average "middle" user:

**The Maximum User** wants depth: detailed logs, progressive overload,
PRs, strength charts, macros, Watch integration, custom programs,
substitutions, volume analytics, recovery analysis, long-term history.

**The Minimum User** might train once every two weeks, open the app for a
short routine, complete only part of a session, forget to log food, buy
the clothing, attend a yoga or spin activation, and still maintain a real
CMSN identity without training like an athlete every day.

CMSN should not build primarily for the average of these two. It should
provide analytical depth for the committed user and one-or-two-tap value
for the inconsistent one. V0 implements this concretely as the
`QuickPathAction` system (`ios/CMSNApp/CMSNApp/Features/Today/QuickPathActions.swift`):
"15 minutes," "dumbbells only," "just walk," "I'm sore," "coming back"
each resolve to a full, real session in one tap, bypassing the standard
rotation entirely.

## 5. Injury, equipment, and kettlebell systems

**Injury/limitation intake** is modeled like selecting a body area on a
diagram — never like a medical intake form. The app can remove or
substitute exercises, reduce expected load, and suggest a recovery session
based on a reported limitation; it cannot diagnose, name a condition,
recommend treatment, or promise rehabilitation. This boundary is enforced
in code (`ios/CMSNApp/CMSNApp/Models/BodyArea.swift`'s
`InjurySafetyLanguage`), not left to per-screen discipline.

Fitbod already ships an "Injury Mode" and recovery-aware recommendations
*(sourced from Fitbod's own public positioning — TechRadar coverage of
Fitbod's feature set, moderate confidence, single-source)*, so
injury-aware substitution alone is not a durable competitive advantage.
CMSN's differentiation has to come from clearer body-area selection,
transparent substitution reasoning ("why this swap"), and integration with
the rest of the loop (readiness, apparel, nutrition) that a
strength-only competitor doesn't have a reason to build.

**Equipment profiles** — Residential Gym, Full-Service Gym, Home, Travel —
are first-class on the athlete/session model, not a settings afterthought.
The residential-gym profile (Smith machine, dumbbells, kettlebells,
cables, bands, a few machines, cardio equipment, studio space) is treated
as the *primary* real-world target, not full-service-gym-first, because
that's what a premium residential building actually provides, and it's
where "I only have dumbbells today" needs to resolve instantly rather than
degrade into a workout that doesn't fit the room the athlete is standing
in.

**Kettlebell training** gets its own program family (Foundations,
Strength, Conditioning, Complexes, 15-Minute, Lower-Impact, and
Kettlebell+Bodyweight hybrids) because it uniquely serves the
small-space, travel-friendly, residential-gym-compatible use case better
than barbell-first programming does.

## 6. Competitive analysis: positioning against Fitbod

Fitbod sells adaptive strength programming: goals, fitness level,
available equipment, progressive overload, muscle recovery, training
history, 1,000+ exercises, video demonstrations, analytics, integrations,
and injury-aware features, at **$15.99/month or $95.99/year**
*(Fitbod's own published pricing at time of writing — verify current
pricing before quoting externally, subscription pricing changes)*.

**CMSN+ pricing: $9.99/month or $59.99/year** (§11) — a real value gap,
but CMSN cannot win by being "Fitbod, cheaper." It has to be broader:

**What CMSN must match:** adaptive workout generation, equipment-aware
programming, goals/experience levels, previous-set history, suggested
weight, progressive overload, muscle recovery, exercise substitutions,
custom exercises, Watch support, workout history, analytics, demo videos,
rest timers, PRs, program editing.

**Where CMSN can exceed Fitbod:**

1. **Whole-day system, not strength-only.** Fitbod addresses strength
   programming; CMSN connects apparel, preparation, strength, cardio,
   yoga, dance, cycling, kettlebells, nutrition, supplement education,
   recovery, events, gifting, and brand membership into one system.
2. **Better beginner interpretation.** Not just "chest fly" — what it is,
   what equipment it needs, what the motion looks like, what muscles to
   feel, common mistakes, a short demo, and an alternative when the
   equipment or confidence isn't there.
3. **Partial-workout intelligence.** Learning that a user habitually stops
   at 35 minutes, or skips floor work, or lacks a specific machine, and
   adjusting the *next* plan — rather than treating completion as binary.
4. **Better return-to-training logic** — CMSN specializes in restoring
   participation after an absence rather than treating it as churn.
5. **Goal flexibility beyond weight loss** — strength, clothing-size,
   body-composition, consistency, event-prep, and return-to-training goals
   are all first-class, because "improvement" isn't universally defined as
   losing weight.
6. **Cross-training breadth** across strength, cardio, cycling, yoga,
   dance, kettlebells, mobility, and recovery.
7. **Apparel and ecosystem integration** Fitbod structurally cannot offer
   — what the user wore, how it performed, what program came bundled with
   a purchase.
8. **Transparent coaching.** Every recommendation should answer "why this?"
   in plain language — "we reduced your shoulder volume because you
   reported significant discomfort and low sleep quality." Fitbod's own
   public positioning acknowledges the industry is moving this direction
   *(TechRadar coverage, moderate confidence)* — CMSN should treat
   explainability as a baseline requirement, not a differentiator that
   stays differentiated for long.
9. **Context-aware short sessions** generated instantly: 10/15/20-minute,
   low-energy, residential-gym, hotel-gym, no-equipment.
10. **Visual and cultural identity** — CMSN should feel like a premium
    brand product, not a utility with fitness content bolted on; this is
    where the black/white/navy design system and the CMSN wordmark
    (already built into the V0 app, reusing the exact SVG paths from the
    marketing site) does real work.

## 7. CMSN Score model

Four dimensions, weighted (implemented in
`ios/CMSNApp/CMSNApp/Features/Score/ScoreCalculator.swift`):

| Dimension | Weight | What it measures |
|---|---|---|
| Work | 25% | Sets, reps, session completion, cardio duration, classes, mobility, walking |
| Consistency | 25% | Returning, following the plan, logging, resuming after a break |
| Progress | 20% | Strength/rep/volume/endurance/mobility improvement, e1RM PRs |
| Discipline & Recovery | 30% | Rest-day adherence, recovery completed, sleep recorded, readiness checked, load reduced when needed, hydration/nutrition habits |

Recovery and rest are weighted **above** raw output on purpose — the score
model should never teach a user that constant exertion equals discipline.
These weights (and the underlying per-action point values in
`ScorePoints`) are explicitly named constants precisely so they're the
first thing tuned once real usage data exists; treat them as a tested
hypothesis, not a finished formula. Concretely, and non-negotiably: a
partial session (2 of 3 sets logged honestly) earns real points, never
zero; a followed rest day earns Discipline credit on par with training;
returning after 7/14/21+ days away earns *positive*, scaled recognition
rather than a reset streak; buying apparel never inflates the training
score — it earns access and status (§9, §10), which is a deliberately
separate currency.

## 8. Nutrition and supplement scope boundaries

The app sits **between a workout tracker and a full food-database app** —
it should not attempt to reproduce MyFitnessPal. In scope: protein/carb/fat
targets (Mifflin-St Jeor + activity-multiplier calorie estimate as
*context*, protein as the headline metric), manual macro entry, saved
meals, quick-add protein/shakes, water tracking, creatine/recovery-shake
habit tracking, and a constraint-based simple-meal engine (high-protein,
low-cost, N-ingredients, time-boxed, no-cook, dietary-flag filtered) drawn
from a small, local, seeded meal list. Out of scope for V0: barcode/
restaurant databases, micronutrient analysis, medical/disease-specific
nutrition, blood-glucose interpretation, medication-related guidance.

**Supplement content is a static education library, not a recommendation
engine.** CMSN does not determine that a user needs a supplement. Every
entry (creatine monohydrate, protein powder, caffeine, electrolytes,
omega-3, vitamin D — see `SupplementLibraryData.swift`) uses hedged
language ("may help support," never "will"), states a general evidence
level, common forms, label-use reminders, cautions, and when to consult a
professional. The FDA's general-wellness product guidance focuses on
low-risk software/products that promote a healthy lifestyle without
making disease, treatment, or prevention claims, and explicitly does not
itself govern dietary supplements as products *(general regulatory
framing — this is not legal advice; any future physical supplement product
CMSN considers selling needs its own separate review under supplement,
labeling, and advertising law, distinct from the app's educational
content)*. The app's job is to stay inside that general-wellness lane:
educate, never personalize a dose, never diagnose.

## 9. Apparel-performance data loop

An optional, post-session, sub-20-second prompt captures: garment worn,
size, stayed-in-place, waistband-secure, restricted-movement,
sweat-managed, seam-irritation, would-wear-again, and a free-text note
(`ApparelFeedbackView`, `ApparelFeedback` model). This is the "Dress" side
of the loop closing back into product decisions — aggregated, consented
feedback can inform fabric, fit, seam placement, pocket placement, and
future product/category decisions the way no competitor's app can,
because no competitor sells the clothes. V0 stores this locally; real
aggregation across the customer base is a V2 backend concern (§12).

## 10. Activations and community

Retail pop-ups are not the primary activation model — activations should
align with how the audience already moves: spin, yoga, dance, kettlebell
clinics, strength foundations, residential-building workouts, walking
clubs, recovery/mobility sessions, beginner orientation, couples
workouts, holiday gift events. **Product-linked programs** tie each
apparel collection to a corresponding experience (Foundation Collection →
a four-week foundation program, Motion Collection → dance/mobility/
conditioning, Strength Collection → a progressive strength block, Ride
Collection → a cycling program, Studio Collection → yoga/Pilates-inspired
work). Purchasing a product grants status, access, program entitlement,
and event eligibility — it does not grant additional CMSN Score, keeping
the training score an honest signal that can't be bought.

## 11. CMSN+ subscription

**Pricing: $9.99/month or $59.99/year, with a 7-day free trial.** Gift
subscriptions supported (ties directly to the gift-buyer relationship in
§2 — holiday commerce should include gift sets, size guidance, gift
receipts, easy exchanges, premium packaging, "buy for him" pathways, and
app-membership gift cards alongside physical product). No lifetime tier
at launch.

**Free tier:** basic workout logging, limited workout generation, core
equipment profiles, basic strength/cardio programs, set/rep/weight
logging, rest timer, basic protein/macro targets, basic score, Health
workout writing, limited exercise videos, local history, partial-session
logging.

**CMSN+:** full adaptive programming, unlimited exercise videos, advanced
strength analytics, recovery-aware adjustments, Apple Watch companion,
full workout sync, advanced macros, the simple meal engine, advanced
training programs, the kettlebell/yoga/dance/cycling/mobility libraries,
equipment-aware travel programming, a custom program builder, plateau
identification, deload recommendations, cloud backup, cross-device
history, product-linked programs, a monthly performance review, apparel-
performance history, founding/collection status, and community
events/challenges.

V0 ships the paywall UI and full StoreKit 2 entitlement plumbing
(`PaywallView`, `StoreKitManager`) with placeholder product IDs — the
actual CMSN+ feature breadth above is built out feature-by-feature in V1,
gated behind the entitlement check that already works end-to-end.

## 12. Roadmap: V0 → V1 → V2

**V0 — CMSN Training Kernel (this build).** Prove the app can guide and
record a useful workout: training + equipment profile, Today screen,
workout generation from the seeded catalog/programs, exercise cues,
sets/reps/weight with native partial completion, rest timer, readiness/
soreness/discomfort capture, session summary, basic CMSN Score, SwiftData
persistence with a real migration plan, unit tests on every logic layer,
iPhone-first with a scaffolded (not implemented) Watch target. *Success
criterion:* a user can open CMSN, get a session that fits their equipment,
understand each exercise, complete any portion of it, and have the result
saved and scored honestly.

**V1 — Complete CMSN Companion.** Adaptive programming across strength/
cardio/kettlebell/walking/mobility/yoga/dance/cycling/recovery; full video
library; macro/protein/water/creatine tracking with meal suggestions; the
full supplement evidence library; a real Apple Watch companion; HealthKit
+ WorkoutKit integration; notifications; product-linked programs; apparel-
performance notes; the full CMSN+ feature set live behind StoreKit;
accessibility and privacy hardening. *Success criterion:* enough
programming, instruction, recovery, nutrition, and wearable value to
justify $9.99/mo or $59.99/yr against Fitbod's $15.99/$95.99.

**V2 — CMSN Ecosystem.** A Supabase backend (auth, cross-device sync,
secure apparel-entitlement codes, gift subscriptions, member status,
collection history), community groups and private circles, event
registration for activations, an explainable adaptive/LLM-backed coaching
engine (the `SuggestionEngine` protocol built in V0 is the seam this
attaches to without touching UI code), apparel-data-informed commerce
personalization, and a coach/instructor portal. *Success criterion:* CMSN
is a connected consumer ecosystem, not a collection of unrelated apparel,
app, and event products.

## 13. North-star metrics

- **Activation:** onboarding completion, first workout started, three sets
  logged, first workout completed *or intentionally ended*, first Watch
  session.
- **Retention:** second workout within 7 days, four-week active rate,
  return rate after inactivity, weekly active users, short-session and
  recovery-day usage.
- **Training value:** recommendation acceptance, workout/partial-session
  completion, substitution rate, PR rate, program progression.
- **Female participation:** active female users, female subscription
  conversion, female apparel/gift purchase, female event participation,
  women using strength programming, cross-category participation — these
  measure inclusion, not a quota that forces women into a narrower content
  slice.
- **Ecosystem:** apparel purchasers activating the app, app users buying
  apparel, product-program redemptions, event registrations, gift
  subscriptions, apparel-feedback completion rate.
- **Subscription:** trial start/conversion, monthly-vs-annual mix, 30/60/90
  day retention, Watch usage, refund rate, reactivation rate.

## 14. Final product doctrine

1. Every completed effort counts.
2. Recovery is part of performance.
3. The app explains what to do and why.
4. Users train with the equipment they actually have.
5. Women participate as athletes, consumers, influencers, and buyers.
6. Men receive meaningful strength and performance tracking.
7. The minimum user gets immediate value.
8. The maximum user gets analytical depth.
9. Apparel purchases create access and history, not artificial athletic
   status.
10. CMSN is present across the full training ecosystem without pretending
    to practice medicine.

CMSN is the system people use to prepare, perform, prove, recover, and
return. Apparel is what they wear inside that system.
