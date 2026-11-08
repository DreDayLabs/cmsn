import type { Metadata } from "next";
import { LegalPage } from "../components/LegalPage";

export const metadata: Metadata = {
  title: "Privacy — CMSN Performance",
  description: "How the CMSN app keeps training data on your iPhone, and what the website invite list stores.",
  alternates: { canonical: "/privacy" },
};

// Mirrors ios/CMSNApp/CMSNApp/App/LegalPages.swift (LegalCopy). Keep in sync.
// Source only. Do not treat a commit as a publish of earnyourcmsn.com.
const sections = [
  { heading: "The Short Version", text: "Training data stays on your iPhone. The app has no account, no ad tracking, and no analytics SDK, and it does not send workouts, meals, or body stats to a CMSN server. If you request an invite on earnyourcmsn.com, that email is stored for the invite list. Deleting the app does not delete that email." },
  { heading: "What's Stored, And Where", text: "Your training profile, body-weight history, workouts, runs, routes, shoes, nutrition logs, saved meals, supplements, and score history are stored in the app's private database on this device only. A photo you attach to a run stays there too. Deleting the app deletes them. You can also erase everything from Settings. If that save fails, Settings shows: Couldn't erase your data. Nothing was confirmed deleted." },
  { heading: "Running", text: "Location is used only while a run is being recorded, including in the background if you allow it, and it stops the moment the run ends. Indoor runs use motion to estimate treadmill distance, and only during that run. Heart rate comes from Apple Health, or from a strap if you turn that option on, and only during the run. A finished run can be written to Apple Health. If Apple Health does not accept the run, it stays on this phone and Run shows the reason, or the words A run is waiting to sync. Runs are private. There is no club and no feed. Pace and distance stay on the phone and are not sent to an analytics service. A run recorded on Apple Watch is copied to this iPhone after." },
  { heading: "Food Lookups", text: "When you scan a barcode or search for a food, the barcode number or search text is sent to Open Food Facts, a non-profit public food database, to fetch nutrition facts. The request sends that barcode or search text, plus a fixed app name in the User-Agent (CMSNApp/0.1). It does not send your name, account, or location. Open Food Facts sees the connection's IP address and states that it retains IP addresses and request logs for three years for security, technical analysis, and popularity measurement. These provider records are not used by CMSN for advertising tracking. The camera is used only to read barcodes; barcode scans are not saved as photos." },
  { heading: "Optional Permissions", text: "Calendar access is off until you turn on Today's calendar in Settings. CMSN does not ask before that. If you turn it on and allow access, CMSN reads the titles of today's events and looks for a workout word. It does not create or edit events. Turning the switch off stops that read. If you deny access, or turn it off later in iOS Settings, the read stops too. The camera is used only to read food barcodes. Location, motion, Bluetooth, and Apple Health are requested only for running, and each one can be denied without blocking the rest of the app. Purchases and subscriptions are handled entirely by Apple; CMSN never sees your payment details." },
  { heading: "Changes", text: "If a future version adds accounts, sync, or anything that moves training data off your device, this policy will change and the app will say so clearly before any of it happens." },
];

export default function Page() {
  return <LegalPage eyebrow="Privacy Policy" title="PRIVACY" sections={sections} />;
}
