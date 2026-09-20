"use client";

import { useEffect, useRef } from "react";

export default function SceneVideo() {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const syncPlayback = () => {
      if (reducedMotion.matches || document.hidden) {
        video.pause();
      } else {
        void video.play().catch(() => {
          // Keep the poster visible if the browser blocks autoplay.
        });
      }
    };

    syncPlayback();
    reducedMotion.addEventListener("change", syncPlayback);
    document.addEventListener("visibilitychange", syncPlayback);
    return () => {
      video.pause();
      reducedMotion.removeEventListener("change", syncPlayback);
      document.removeEventListener("visibilitychange", syncPlayback);
    };
  }, []);

  return (
    <video
      ref={videoRef}
      className="scene-background scene-background--video"
      src="/art/drift-desert-loop.mp4"
      poster="/art/drift-desert-night.png"
      autoPlay
      muted
      loop
      playsInline
      preload="auto"
      aria-hidden="true"
      onError={(event) => { event.currentTarget.hidden = true; }}
    />
  );
}
