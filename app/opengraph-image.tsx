import { ImageResponse } from "next/og";
import { CMSN_LOCKUP } from "@/lib/brand-mark";

export const alt = "CMSN — Earn Your CMSN";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

// Satori renders a flat <svg><path/> reliably; it does not handle nested SVG
// or transform groups, which is why lib/brand-mark.ts keeps the lockup as a
// single transform-free path.
const LOCKUP_WIDTH = 820;

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "#0A0A0A",
          gap: 64,
        }}
      >
        <svg
          width={LOCKUP_WIDTH}
          height={Math.round(LOCKUP_WIDTH / CMSN_LOCKUP.aspect)}
          viewBox={CMSN_LOCKUP.viewBox}
          fill="#FAFAF8"
        >
          <path d={CMSN_LOCKUP.path} />
        </svg>
        <div
          style={{
            color: "rgba(250,250,248,0.6)",
            fontSize: 26,
            letterSpacing: 16,
            display: "flex",
          }}
        >
          EARN YOUR CMSN
        </div>
      </div>
    ),
    { ...size }
  );
}
