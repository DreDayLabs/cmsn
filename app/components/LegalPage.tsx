import Link from "next/link";

type Section = { heading: string; text: string };

export function LegalPage({
  eyebrow,
  title,
  sections,
}: {
  eyebrow: string;
  title: string;
  sections: Section[];
}) {
  return (
    <main className="min-h-screen bg-black text-white">
      <div className="mx-auto max-w-2xl px-6 py-16">
        <Link href="/" className="text-xs uppercase tracking-[0.3em] text-white/60 hover:text-white">
          CMSN Performance
        </Link>
        <p className="mt-10 text-xs uppercase tracking-[0.3em] text-white/60">{eyebrow}</p>
        <h1 className="mt-2 text-4xl font-bold tracking-tight">{title}</h1>
        <div className="mt-10 space-y-8">
          {sections.map((s) => (
            <section key={s.heading}>
              <h2 className="text-xs uppercase tracking-[0.3em] text-white/60">{s.heading}</h2>
              <p className="mt-2 leading-relaxed text-white/90">{s.text}</p>
            </section>
          ))}
        </div>
        <p className="mt-12 text-sm text-white/50">Last updated November 2026</p>
        <nav className="mt-6 flex gap-6 text-sm text-white/60">
          <Link href="/privacy" className="hover:text-white">Privacy</Link>
          <Link href="/support" className="hover:text-white">Support</Link>
          <a href="mailto:support@earnyourcmsn.com" className="hover:text-white">support@earnyourcmsn.com</a>
        </nav>
      </div>
    </main>
  );
}
