import { CMSN_LOCKUP, CMSN_SYMBOL } from "@/lib/brand-mark";
import SignupForm from "@/app/components/SignupForm";

/**
 * CMSN — app landing page.
 *
 * Deliberately carries no product grid and no photography. The app exists;
 * the apparel does not yet, and there are no CMSN photographs. Borrowing
 * stock imagery to stand in for either would make a claim the house cannot
 * currently support, so the page is mark-led and typographic instead.
 *
 * Type is the Helvetica stack already declared in globals.css. CMSN has not
 * chosen a brand typeface; that decision stays open rather than being made
 * here by accident.
 */

const Wordmark = ({ height = 18 }: { height?: number }) => (
  <svg
    height={height}
    viewBox={CMSN_LOCKUP.viewBox}
    fill="currentColor"
    role="img"
    aria-label="CMSN"
    style={{ display: "block" }}
  >
    <path d={CMSN_LOCKUP.path} />
  </svg>
);

const Symbol = ({ height = 24 }: { height?: number }) => (
  <svg
    height={height}
    viewBox={CMSN_SYMBOL.viewBox}
    fill="currentColor"
    role="presentation"
    aria-hidden="true"
    style={{ display: "block" }}
  >
    <path d={CMSN_SYMBOL.path} />
  </svg>
);

/** Weights are the real ones, from ios/…/Features/Score/ScoreCalculator.swift. */
const SCORE = [
  {
    name: "Discipline & Recovery",
    weight: "30%",
    note: "Rest and recovery weigh more than raw output. That is the argument, not a concession.",
  },
  { name: "Work", weight: "25%", note: "Sets attempted, sessions finished." },
  { name: "Consistency", weight: "25%", note: "Showing up on schedule. Returning after time away." },
  { name: "Progress", weight: "20%", note: "Estimated one-rep-max movement over time." },
];

const FEATURES = [
  { name: "Today", note: "One session, built for the day you are actually having." },
  { name: "Train", note: "Programmes that resolve around your equipment, injuries and limitations." },
  { name: "Fuel", note: "Barcode scan, food search, meal builder, saved meals, macro targets." },
  { name: "Recover", note: "Readiness checks that change the session instead of judging it." },
  { name: "Prove", note: "Your Score, and a card worth sending." },
];

export default function Page() {
  return (
    <div className="flex min-h-full flex-col bg-[var(--cmsn-off-black)] text-[var(--cmsn-off-white)]">
      <header className="mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-7">
        <Wordmark height={16} />
        <span className="text-[10px] uppercase tracking-[0.28em] text-white/40">
          Earned, not given
        </span>
      </header>

      <main className="flex-1">
        {/* Hero */}
        <section className="mx-auto w-full max-w-5xl px-6 pt-16 pb-24 sm:pt-28 sm:pb-32">
          <h1 className="max-w-[14ch] text-[clamp(2.75rem,9vw,6.5rem)] font-medium uppercase leading-[0.92] tracking-[-0.01em]">
            Earn your
            <br />
            CMSN.
          </h1>

          <p className="mt-8 max-w-[44ch] text-lg leading-relaxed text-white/70">
            Nobody hands this out. You put in the work — the app just keeps score.
          </p>

          <div className="mt-12">
            <p className="mb-4 text-[11px] uppercase tracking-[0.24em] text-white/40">
              The app is in private build. Invites go out first to this list.
            </p>
            <SignupForm source="web-hero" />
          </div>
        </section>

        <hr className="mx-auto w-full max-w-5xl border-white/10" />

        {/* The Score */}
        <section className="mx-auto w-full max-w-5xl px-6 py-24 sm:py-32">
          <div className="flex items-baseline gap-4">
            <Symbol height={20} />
            <h2 className="text-[11px] uppercase tracking-[0.24em] text-white/40">
              The CMSN Score
            </h2>
          </div>

          <p className="mt-8 max-w-[52ch] text-2xl leading-snug sm:text-3xl">
            Real work keeps score. Four dimensions, weighted — and recovery
            carries the most.
          </p>

          <dl className="mt-16 grid gap-px border border-white/10 bg-white/10 sm:grid-cols-2">
            {SCORE.map((dimension) => (
              <div
                key={dimension.name}
                className="bg-[var(--cmsn-off-black)] p-7 sm:p-9"
              >
                <div className="flex items-baseline justify-between gap-4">
                  <dt className="text-sm uppercase tracking-[0.14em]">
                    {dimension.name}
                  </dt>
                  <span className="text-2xl tabular-nums text-white/50">
                    {dimension.weight}
                  </span>
                </div>
                <dd className="mt-4 text-[15px] leading-relaxed text-white/55">
                  {dimension.note}
                </dd>
              </div>
            ))}
          </dl>

          <p className="mt-8 max-w-[56ch] text-sm leading-relaxed text-white/40">
            Points are whole numbers you can reason about. A partial session is
            never zero and is never penalised. The weights are a stated
            hypothesis, and they get tuned once there is real training data
            behind them.
          </p>
        </section>

        <hr className="mx-auto w-full max-w-5xl border-white/10" />

        {/* What is in it */}
        <section className="mx-auto w-full max-w-5xl px-6 py-24 sm:py-32">
          <h2 className="text-[11px] uppercase tracking-[0.24em] text-white/40">
            In the app
          </h2>

          <ul className="mt-12 divide-y divide-white/10 border-y border-white/10">
            {FEATURES.map((feature) => (
              <li
                key={feature.name}
                className="grid gap-2 py-7 sm:grid-cols-[10rem_1fr] sm:gap-8"
              >
                <h3 className="text-sm uppercase tracking-[0.14em]">
                  {feature.name}
                </h3>
                <p className="text-[15px] leading-relaxed text-white/55">
                  {feature.note}
                </p>
              </li>
            ))}
          </ul>

          <p className="mt-10 text-sm text-white/40">
            iPhone and Apple Watch.
          </p>
        </section>

        <hr className="mx-auto w-full max-w-5xl border-white/10" />

        {/* Apparel — stated plainly, not sold */}
        <section className="mx-auto w-full max-w-5xl px-6 py-24 sm:py-32">
          <h2 className="text-[11px] uppercase tracking-[0.24em] text-white/40">
            Apparel
          </h2>
          <p className="mt-8 max-w-[48ch] text-2xl leading-snug sm:text-3xl">
            Collection 01 is in development. Black and white, symbol-led.
          </p>
          <p className="mt-6 max-w-[52ch] text-[15px] leading-relaxed text-white/55">
            Nothing is for sale yet, and there are no product photographs to
            show. When there are, they will be of real garments. The list above
            hears about it first.
          </p>
        </section>
      </main>

      <footer className="mx-auto w-full max-w-5xl px-6 pb-16">
        <div className="flex flex-col gap-6 border-t border-white/10 pt-10 sm:flex-row sm:items-center sm:justify-between">
          <Wordmark height={14} />
          <p className="text-[10px] uppercase tracking-[0.22em] text-white/35">
            © {new Date().getFullYear()} CMSN
          </p>
        </div>
      </footer>
    </div>
  );
}
