"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { flushSync } from "react-dom";

const POSTER = "/videos/apparel-loop-poster.jpg";
const SRC = "/videos/apparel-loop.mp4";

/** Phone stays a full-bleed cover, biased to the top of the portrait frame. */
const MOBILE_POSITION = "50% 0%";

/**
 * Desktop shows the whole 9:16 frame in a right-hand column, so a landscape
 * crop cannot cut the athlete out as he drops into the squat. The left edge
 * feathers into the section's off-black, where the type sits.
 */
const DESKTOP_COLUMN = "calc(100svh * 9 / 16)";
const DESKTOP_FADE =
  "linear-gradient(to right, var(--cmsn-off-black) 0%, color-mix(in srgb, var(--cmsn-off-black) 45%, transparent) 7%, transparent 16%)";

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
  const [wide, setWide] = useState(false);

  useEffect(() => {
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const narrow = window.matchMedia("(max-width: 639px)");

    const sync = () => {
      const reduce = motion.matches;
      const mobile = narrow.matches;
      setWide(!mobile);
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
      <div className="absolute inset-0 sm:hidden">
        <Image
          src={POSTER}
          alt=""
          fill
          priority
          sizes="100vw"
          className="object-cover"
          style={{ objectPosition: MOBILE_POSITION }}
        />
        {!wide && playing ? (
          <video
            ref={videoRef}
            className="absolute inset-0 h-full w-full object-cover motion-reduce:hidden"
            style={{ objectPosition: MOBILE_POSITION }}
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
            <img src={POSTER} alt="" style={{ objectPosition: MOBILE_POSITION }} />
          </video>
        ) : null}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0"
          style={{ backgroundImage: SCRIM_MOBILE }}
        />
      </div>

      <div
        className="absolute inset-y-0 right-0 hidden h-full sm:block"
        style={{ width: DESKTOP_COLUMN }}
      >
        <Image
          src={POSTER}
          alt=""
          fill
          priority
          sizes="40vw"
          className="object-cover"
          style={{ objectPosition: "50% 50%" }}
        />
        {wide && playing ? (
          <video
            ref={videoRef}
            className="absolute inset-0 h-full w-full object-cover motion-reduce:hidden"
            style={{ objectPosition: "50% 50%" }}
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
            <img src={POSTER} alt="" style={{ objectPosition: "50% 50%" }} />
          </video>
        ) : null}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0"
          style={{ backgroundImage: DESKTOP_FADE }}
        />
      </div>

      <style>{`
        @media (min-width: 640px) {
          .apparel-copy {
            padding-right: max(1.5rem, calc(100svh * 9 / 16 + 2.5rem - (100vw - 64rem) / 2));
          }
        }
      `}</style>
      <div className="apparel-copy relative z-10 mx-auto flex min-h-[100svh] w-full max-w-5xl flex-col px-6 py-24 sm:py-32">
        <h2 className="text-[11px] uppercase tracking-[0.24em] text-white/40">
          Apparel
        </h2>
        <p className="mt-8 max-w-[48ch] text-2xl leading-snug sm:text-3xl">
          Collection 01 is in development. Black and white,{" "}
          <span className="whitespace-nowrap">symbol-led.</span>
        </p>
        <p className="mt-6 max-w-[52ch] text-[15px] font-normal leading-relaxed text-white/55">
          Nothing is for sale yet — this is the world it&apos;s being built
          for.
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
          className="absolute inset-0 h-full w-full object-cover sm:hidden"
          style={{ objectPosition: MOBILE_POSITION }}
        />
        {/* eslint-disable-next-line @next/next/no-img-element -- noscript cannot run the image optimizer */}
        <img
          src={POSTER}
          alt=""
          className="absolute inset-y-0 right-0 hidden h-full object-cover sm:block"
          style={{ width: DESKTOP_COLUMN, objectPosition: "50% 50%" }}
        />
      </noscript>
    </section>
  );
}
