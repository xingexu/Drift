"use client";
import { useEffect, useRef, useState } from "react";

function Counter({ target, suffix = "" }: { target: number; suffix?: string }) {
  const [count, setCount] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const started = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !started.current) {
          started.current = true;
          const duration = 1400;
          const steps = 50;
          const inc = target / steps;
          let cur = 0;
          const t = setInterval(() => {
            cur = Math.min(cur + inc, target);
            setCount(Math.round(cur));
            if (cur >= target) clearInterval(t);
          }, duration / steps);
        }
      },
      { threshold: 0.5 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [target]);

  return (
    <span ref={ref}>
      {count.toLocaleString()}
      {suffix}
    </span>
  );
}

export function AnimatedStats() {
  return (
    <div className="stats-row" data-reveal>
      <div className="stats-item">
        <div className="stats-num">
          <Counter target={14800} suffix="+" />
        </div>
        <div className="stats-label">Sessions tracked</div>
      </div>
      <div className="stats-div" />
      <div className="stats-item">
        <div className="stats-num">
          <Counter target={2400} suffix="+" />
        </div>
        <div className="stats-label">Active users</div>
      </div>
      <div className="stats-div" />
      <div className="stats-item">
        <div className="stats-num">
          <Counter target={89} suffix="%" />
        </div>
        <div className="stats-label">Report better focus</div>
      </div>
      <div className="stats-div" />
      <div className="stats-item">
        <div className="stats-num">4.8★</div>
        <div className="stats-label">Average rating</div>
      </div>
    </div>
  );
}
