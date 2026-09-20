"use client";

import { useEffect, useRef, useState, type CSSProperties } from "react";

type Meteor = {
  id: number;
  startX: number;
  startY: number;
  endX: number;
  endY: number;
  duration: number;
  delay: number;
};

export default function ShootingStars() {
  const layerRef = useRef<HTMLDivElement>(null);
  const [meteors, setMeteors] = useState<Meteor[]>([]);

  useEffect(() => {
    const layer = layerRef.current;
    if (!layer) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let timer: ReturnType<typeof setTimeout> | undefined;
    let nextId = 0;
    let disposed = false;

    const launchBurst = () => {
      if (disposed || reducedMotion.matches || document.hidden) return;
      const { width, height } = layer.getBoundingClientRect();
      const count = 1 + Math.floor(Math.random() * 3);
      const stagger = 380 + Math.random() * 420;
      const burst = Array.from({ length: count }, (_, index) => {
        const fromTop = Math.random() < .3;
        // The head starts outside the viewport; the whole tail exits before removal.
        const startX = fromTop ? width * Math.random() * .25 : -180;
        const startY = fromTop ? -180 : height * (.02 + Math.random() * .38);
        const endX = width + 220;
        const endY = height * (.72 + Math.random() * .28) + 100;
        const distance = Math.hypot(endX - startX, endY - startY);
        return {
          id: nextId++, startX, startY, endX, endY,
          duration: Math.max(3200, distance / (310 + Math.random() * 120) * 1000),
          delay: index * stagger,
        };
      });
      setMeteors((current) => [...current, ...burst]);
      const finish = Math.max(...burst.map((meteor) => meteor.duration + meteor.delay));
      timer = setTimeout(launchBurst, finish + 1800 + Math.random() * 4200);
    };

    const syncActivity = () => {
      clearTimeout(timer);
      if (reducedMotion.matches || document.hidden) {
        setMeteors([]);
      } else {
        timer = setTimeout(launchBurst, 900 + Math.random() * 1100);
      }
    };

    syncActivity();
    reducedMotion.addEventListener("change", syncActivity);
    document.addEventListener("visibilitychange", syncActivity);
    return () => {
      disposed = true;
      clearTimeout(timer);
      reducedMotion.removeEventListener("change", syncActivity);
      document.removeEventListener("visibilitychange", syncActivity);
    };
  }, []);

  return (
    <div ref={layerRef} className="sky-meteors" aria-hidden="true">
      {meteors.map((meteor) => {
        const angle = Math.atan2(meteor.endY - meteor.startY, meteor.endX - meteor.startX);
        return (
          <span key={meteor.id} className="sky-meteor" style={{
            "--meteor-start-x": `${meteor.startX}px`,
            "--meteor-start-y": `${meteor.startY}px`,
            "--meteor-end-x": `${meteor.endX}px`,
            "--meteor-end-y": `${meteor.endY}px`,
            animationDuration: `${meteor.duration}ms`,
            animationDelay: `${meteor.delay}ms`,
          } as CSSProperties}
            onAnimationEnd={() => setMeteors((current) => current.filter(({ id }) => id !== meteor.id))}
          >
            <svg className="sky-meteor__sprite" viewBox="0 0 200 200" focusable="false">
              {Array.from({ length: 18 }, (_, index) => (
                <rect key={index}
                  x={180 - Math.round(Math.cos(angle) * index * 8 / 2) * 2}
                  y={180 - Math.round(Math.sin(angle) * index * 8 / 2) * 2}
                  width={index < 4 ? 6 : 4} height={index < 4 ? 6 : 4}
                  fill={index < 4 ? "#ffffff" : index < 11 ? "#ffe8bd" : "#c6b8ed"}
                  opacity={1 - index / 19} />
              ))}
              <path d="M180 176h6v4h4v6h-4v4h-6v-4h-4v-6h4z" fill="#fffef3" />
            </svg>
          </span>
        );
      })}
    </div>
  );
}
