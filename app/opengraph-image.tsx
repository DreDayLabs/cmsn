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
        <svg width={620} viewBox="0 0 344 100" fill="none">
          <g stroke="#FAFAF8" strokeWidth={10} strokeLinecap="round" strokeLinejoin="round">
            <path d="M58 10 H32 Q10 10 10 32 V68 Q10 90 32 90 H58" />
            <path d="M82 90 L93 10 L108 62 L123 10 L134 90" />
            <path d="M204 12 H178 Q160 12 160 30 Q160 47 178 49 L186 50 Q204 52 204 69 Q204 88 186 88 H160" />
            <path d="M232 90 V10 L280 90 V10" />
          </g>
          <g stroke="#FAFAF8" strokeWidth={10} strokeLinecap="butt">
            <path d="M290 90 L310 10" />
            <path d="M314 90 L334 10" />
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
