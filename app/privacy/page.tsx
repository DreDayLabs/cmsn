import type { Metadata } from "next";
import { LegalPage } from "../components/LegalPage";

export const metadata: Metadata = {
  title: "Privacy — CMSN Performance",
  description: "How CMSN Performance handles your data: on your device only, no accounts, no tracking.",
  alternates: { canonical: "/privacy" },
};

// Mirrors ios/CMSNApp/CMSNApp/App/LegalPages.swift (Privacy Policy). Keep in sync.
const sections = [
  { heading: "The Short Version", text: "Your data stays on your phone. CMSN has no server, no account system, and no analytics or ad tracking. We can't see your workouts, your meals, or your body stats — nobody can but you." },
  { heading: "What's Stored, And Where", text: "Your training profile, body-weight history, workouts, runs, routes, shoes, nutrition logs, saved meals, supplements, and score history are stored in the app's private database on this device only. A photo you attach to a run stays there too. Deleting the app deletes them. You can also erase everything from Settings at any time." },
  { heading: "Running", text: "Location is used only while a run is being recorded, including in the background if you allow it, and it stops the moment the run ends. Indoor runs use motion to estimate treadmill distance, and only during that run. Heart rate comes from Apple Health, or from a strap if you turn that option on, and only during the run. A finished run can be written to Apple Health. If you later turn Health access off, the run stays on this phone and the app says sync is waiting — it does not drop the workout quietly. Runs are private. There is no club, no feed, and no analytics in the run. A run recorded on Apple Watch is copied to this iPhone after." },
  { heading: "Food Lookups", text: "When you scan a barcode or search for a food, the barcode number or search text is sent to Open Food Facts, a non-profit public food database, to fetch nutrition facts. Nothing about you goes with it — no name, no identifier, no location. The camera is used only to read barcodes; barcode scans are not saved as photos." },
  { heading: "Optional Permissions", text: "Calendar access is optional, off by default, and used only to see whether today has a scheduled workout. The camera is used only to read food barcodes. Location, motion, Bluetooth, and Apple Health are requested only for running, and each one can be denied without blocking the rest of the app. Purchases and subscriptions are handled entirely by Apple; CMSN never sees your payment details." },
  { heading: "Changes", text: "If a future version adds accounts, sync, or anything that moves data off your device, this policy will change and the app will say so clearly before any of it happens." },
];

export default function Page() {
  return <LegalPage eyebrow="Privacy Policy" title="PRIVACY" sections={sections} />;
}
