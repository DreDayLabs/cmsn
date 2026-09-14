import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CMSN — Earn Your CMSN",
  description:
    "Fashion-grade training wear for the walk to the gym — built big-man-first. Black, white, navy. Earned, not given. New York City.",
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
