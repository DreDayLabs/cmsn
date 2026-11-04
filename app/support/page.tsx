import type { Metadata } from "next";
import { LegalPage } from "../components/LegalPage";

export const metadata: Metadata = {
  title: "Support — CMSN Performance",
  description: "Get help with CMSN Performance: contact, data export and deletion, and subscriptions.",
  alternates: { canonical: "/support" },
};

// Mirrors ios/CMSNApp/CMSNApp/App/LegalPages.swift (Help & Contact). Keep in sync.
const sections = [
  { heading: "Get In Touch", text: "Questions, bugs, or ideas — email support@earnyourcmsn.com and include what you were doing when the problem happened. Screenshots help." },
  { heading: "Your Data", text: "Everything lives on your device. Settings → Export My Data gives you a full copy as a readable file; Settings → Delete Everything erases it permanently." },
  { heading: "Subscriptions", text: "CMSN+ billing is managed by Apple. To change or cancel, open iPhone Settings → your name → Subscriptions. Refunds are requested through Apple at reportaproblem.apple.com." },
  { heading: "A Note On Health", text: "CMSN is a training log and education tool, not medical advice. Talk to a professional before changing your training, diet, or supplements — especially with an injury or health condition." },
];

export default function Page() {
  return <LegalPage eyebrow="Help & Contact" title="SUPPORT" sections={sections} />;
}
