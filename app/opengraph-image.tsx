import { ImageResponse } from "next/og";

export const alt = "CMSN — Earn Your CMSN";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

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
        <svg width={680} viewBox="0 0 420 100" fill="none">
          <g stroke="#FAFAF8" strokeWidth={10} strokeLinecap="round" strokeLinejoin="round">
            <path d="M58 10 H32 Q10 10 10 32 V68 Q10 90 32 90 H58" />
            <path d="M104 90 L115 10 L130 62 L145 10 L156 90" />
            <path d="M248 12 H222 Q204 12 204 30 Q204 47 222 49 L230 50 Q248 52 248 69 Q248 88 230 88 H204" />
            <path d="M298 90 V10 L346 90 V10" />
          </g>
          <g stroke="#FAFAF8" strokeWidth={10} strokeLinecap="butt">
            <path d="M362 90 L382 10" />
            <path d="M386 90 L406 10" />
          </g>
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
