import type { Metadata } from "next";
import { LegalPage } from "../components/LegalPage";

export const metadata: Metadata = {
  title: "Support — CMSN Performance",
  description: "Help with CMSN Performance: contact, the partial data export, deletion, and subscriptions.",
  alternates: { canonical: "/support" },
};

// Mirrors ios/CMSNApp/CMSNApp/App/LegalPages.swift (LegalCopy.yourData). Keep in sync.
// Source only. Do not treat a commit as a publish of earnyourcmsn.com.
const sections = [
  { heading: "Get In Touch", text: "Questions, bugs, or ideas — email support@earnyourcmsn.com and include what you were doing when the problem happened. Screenshots help." },
  { heading: "Your Data", text: "Training data lives on this iPhone. Settings → Export My Data writes a JSON file of the profile summary, workout sessions, nutrition logs, saved meals, custom supplements, weight entries, finished-run summaries, and score events. It does not include route coordinates, split times, shoes, the run photo, readiness checks, injury notes, or set effort (RPE). A finished run is marked photoAttached when a photo is stored. Settings → Delete Everything removes the on-device records, including records the export leaves out. If that save fails, Settings shows: Couldn't erase your data. Nothing was confirmed deleted." },
  { heading: "Subscriptions", text: "CMSN+ billing is managed by Apple. To change or cancel, open iPhone Settings → your name → Subscriptions. Refunds are requested through Apple at reportaproblem.apple.com." },
  { heading: "A Note On Health", text: "CMSN is a training log and education tool, not medical advice. Talk to a professional before changing your training, diet, or supplements — especially with an injury or health condition." },
];

export default function Page() {
  return <LegalPage eyebrow="Help & Contact" title="SUPPORT" sections={sections} />;
}
