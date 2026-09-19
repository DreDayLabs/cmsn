import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CMSN — Earn Your CMSN",
  description:
    "A training app that keeps score. Four weighted dimensions, with discipline and recovery carrying the most. Earned, not given. Request an invite.",
  metadataBase: new URL("https://earnyourcmsn.com"),
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
