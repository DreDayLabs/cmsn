"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { flushSync } from "react-dom";

const POSTER = "/videos/apparel-loop-poster.jpg";
const SRC = "/videos/apparel-loop.mp4";

/**
 * The loop is portrait and the head sits on the top edge of the frame.
 * Top alignment keeps the crown in view on a landscape desktop; the sides
 * are already fully visible there, and on a phone this stays centered.
 */
const FRAME_POSITION = "50% 0%";

/**
 * Off-black only. A top veil over the type, lighter at the crown, then a
 * long fall so the chest and the rest of the film read. A shorter
 * left-to-right fade keeps the window on the right from sitting under a
 * second plate. Mobile type runs the full width, so the top fade carries
 * the contrast and then opens toward the feet.
 */
const SCRIM_DESKTOP = [
  "linear-gradient(to right, color-mix(in srgb, var(--cmsn-off-black) 42%, transparent) 0%, color-mix(in srgb, var(--cmsn-off-black) 30%, transparent) 25%, color-mix(in srgb, var(--cmsn-off-black) 14%, transparent) 45%, color-mix(in srgb, var(--cmsn-off-black) 4%, transparent) 62%, transparent 100%)",
  "linear-gradient(to bottom, color-mix(in srgb, var(--cmsn-off-black) 62%, transparent) 0%, color-mix(in srgb, var(--cmsn-off-black) 72%, transparent) 14%, color-mix(in srgb, var(--cmsn-off-black) 80%, transparent) 28%, color-mix(in srgb, var(--cmsn-off-black) 82%, transparent) 42%, color-mix(in srgb, var(--cmsn-off-black) 70%, transparent) 50%, color-mix(in srgb, var(--cmsn-off-black) 50%, transparent) 56%, color-mix(in srgb, var(--cmsn-off-black) 32%, transparent) 62%, color-mix(in srgb, var(--cmsn-off-black) 8%, transparent) 74%, transparent 88%)",
].join(", ");

const SCRIM_MOBILE = [
  "linear-gradient(to right, color-mix(in srgb, var(--cmsn-off-black) 45%, transparent) 0%, color-mix(in srgb, var(--cmsn-off-black) 20%, transparent) 40%, color-mix(in srgb, var(--cmsn-off-black) 5%, transparent) 75%, transparent 100%)",
  "linear-gradient(to bottom, color-mix(in srgb, var(--cmsn-off-black) 88%, transparent) 0%, color-mix(in srgb, var(--cmsn-off-black) 86%, transparent) 20%, color-mix(in srgb, var(--cmsn-off-black) 84%, transparent) 50%, color-mix(in srgb, var(--cmsn-off-black) 35%, transparent) 66%, color-mix(in srgb, var(--cmsn-off-black) 8%, transparent) 84%, transparent 100%)",
].join(", ");

/**
 * Apparel background.
 *
 * The loop is a byte copy of one Higgsfield original. It plays on desktop
 * only. Mobile and prefers-reduced-motion stay on the poster so the section
 * never autoplays on a phone and never moves when motion is reduced. The
 * poster is in the first paint either way, including when JavaScript is off.
 */
export default function ApparelSection() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [playing, setPlaying] = useState(false);
  const [canOfferPlay, setCanOfferPlay] = useState(false);

  useEffect(() => {
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const narrow = window.matchMedia("(max-width: 639px)");

    const sync = () => {
      const reduce = motion.matches;
      const mobile = narrow.matches;
      setCanOfferPlay(!reduce && mobile);
      if (reduce) {
        setPlaying(false);
        return;
      }
      if (!mobile) setPlaying(true);
    };

    sync();
    motion.addEventListener("change", sync);
    narrow.addEventListener("change", sync);
    return () => {
      motion.removeEventListener("change", sync);
      narrow.removeEventListener("change", sync);
    };
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (!playing) {
      video.pause();
      return;
    }
    video.play().catch(() => setPlaying(false));
  }, [playing]);

  function playFromTap() {
    flushSync(() => setPlaying(true));
    videoRef.current?.play().catch(() => setPlaying(false));
  }

  return (
    <section className="relative isolate min-h-[100svh] overflow-hidden bg-[var(--cmsn-off-black)] text-[var(--cmsn-off-white)]">
      <Image
        src={POSTER}
        alt=""
        fill
        priority
        sizes="100vw"
        className="object-cover"
        style={{ objectPosition: FRAME_POSITION }}
      />

      {playing ? (
        <video
          ref={videoRef}
          className="absolute inset-0 h-full w-full object-cover motion-reduce:hidden"
          style={{ objectPosition: FRAME_POSITION }}
          autoPlay
          muted
          loop
          playsInline
          poster={POSTER}
          preload="auto"
          aria-hidden="true"
        >
          <source src={SRC} type="video/mp4" />
          {/* eslint-disable-next-line @next/next/no-img-element -- paints only when the browser cannot play video */}
          <img src={POSTER} alt="" style={{ objectPosition: FRAME_POSITION }} />
        </video>
      ) : null}

      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 sm:hidden"
        style={{ backgroundImage: SCRIM_MOBILE }}
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 hidden sm:block"
        style={{ backgroundImage: SCRIM_DESKTOP }}
      />

      <div className="relative z-10 mx-auto flex min-h-[100svh] w-full max-w-5xl flex-col px-6 py-24 sm:py-32">
        <h2 className="text-[11px] uppercase tracking-[0.24em] text-white/40">
          Apparel
        </h2>
        <p className="mt-8 max-w-[48ch] text-2xl leading-snug sm:text-3xl">
          Collection 01 is in development. Black and white,{" "}
          <span className="whitespace-nowrap">symbol-led.</span>
        </p>
        <p className="mt-6 max-w-[52ch] text-[15px] leading-relaxed text-white/55">
          Nothing is for sale yet, and there are no product photographs to
          show. When there are, they will be of real garments. The list above
          hears about it first.
        </p>

        {canOfferPlay && !playing ? (
          <button
            type="button"
            onClick={playFromTap}
            className="absolute bottom-8 right-6 text-[11px] uppercase tracking-[0.24em] text-white/40"
          >
            Play
          </button>
        ) : null}
      </div>

      <noscript>
        {/* eslint-disable-next-line @next/next/no-img-element -- noscript cannot run the image optimizer */}
        <img
          src={POSTER}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
          style={{ objectPosition: FRAME_POSITION }}
        />
      </noscript>
    </section>
  );
}
