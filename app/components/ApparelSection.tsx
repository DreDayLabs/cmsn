"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { flushSync } from "react-dom";

const POSTER = "/videos/apparel-loop-poster.jpg";
const SRC = "/videos/apparel-loop.mp4";

/**
 * Apparel background.
 *
 * The loop is a byte copy of one Higgsfield original. It plays on desktop
 * only. Mobile and prefers-reduced-motion stay on the poster so the section
 * never autoplays on a phone and never moves when motion is reduced. The
 * poster is in the first paint either way, including when JavaScript is off.
 *
 * Overlays use --cmsn-off-black only. The top scrim is solid through the
 * copy, then falls away so the loop can show; the bottom scrim meets the
 * footer.
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
      />

      {playing ? (
        <video
          ref={videoRef}
          className="absolute inset-0 h-full w-full object-cover motion-reduce:hidden"
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
          <img src={POSTER} alt="" />
        </video>
      ) : null}

      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0"
        style={{
          backgroundImage:
            "linear-gradient(to bottom, var(--cmsn-off-black) 0%, var(--cmsn-off-black) 52%, color-mix(in srgb, var(--cmsn-off-black) 40%, transparent) 74%, transparent 100%), linear-gradient(to top, var(--cmsn-off-black) 0%, transparent 28%)",
        }}
      />

      <div className="relative z-10 mx-auto flex min-h-[100svh] w-full max-w-5xl flex-col px-6 py-24 sm:py-32">
        <h2 className="text-[11px] uppercase tracking-[0.24em] text-white/40">
          Apparel
        </h2>
        <p className="mt-8 max-w-[48ch] text-2xl leading-snug sm:text-3xl">
          Collection 01 is in development. Black and white, symbol-led.
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
        />
      </noscript>
    </section>
  );
}
