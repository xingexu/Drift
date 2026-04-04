// ---------------------------------------------------------------------------
// Drift – Logo + Icons (pure HTML, no SVG text)
// ---------------------------------------------------------------------------

/**
 * Wordmark as plain HTML. No SVG text rendering issues.
 */
export function driftLogo(size: number = 15): string {
  return `<span style="
    font-family: Inter, -apple-system, sans-serif;
    font-size: ${size}px;
    font-weight: 700;
    letter-spacing: -0.03em;
    color: var(--text-primary);
    display: inline-flex;
    align-items: center;
    gap: 0;
    user-select: none;
  ">drift</span>`;
}

// ---------------------------------------------------------------------------
// Inline SVG icons (simple, crisp, 20x20 default)
// ---------------------------------------------------------------------------

const icon = (d: string, size = 20) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><${d}/></svg>`;

export const icons = {
  clock: (s?: number) => icon('circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"', s),
  target: (s?: number) => icon('circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"', s),
  zap: (s?: number) => icon('polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"', s),
  globe: (s?: number) => icon('circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"', s),
  trendingDown: (s?: number) => icon('polyline points="23 18 13.5 8.5 8.5 13.5 1 6"/><polyline points="17 18 23 18 23 12"', s),
  activity: (s?: number) => icon('polyline points="22 12 18 12 15 21 9 3 6 12 2 12"', s),
  alertCircle: (s?: number) => icon('circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"', s),
  arrowRight: (s?: number) => icon('line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"', s),
  sun: (s?: number) => icon('circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"', s),
  moon: (s?: number) => icon('path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"', s),
  download: (s?: number) => icon('path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"', s),
  trash: (s?: number) => icon('polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"', s),
  shield: (s?: number) => icon('path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"', s),
  layers: (s?: number) => icon('polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"', s),
  crosshair: (s?: number) => icon('circle cx="12" cy="12" r="10"/><line x1="22" y1="12" x2="18" y2="12"/><line x1="6" y1="12" x2="2" y2="12"/><line x1="12" y1="6" x2="12" y2="2"/><line x1="12" y1="22" x2="12" y2="18"', s),
};

/**
 * Static icon SVG for PNG generation.
 */
export const DRIFT_ICON_SVG = `<svg width="128" height="128" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="128" height="128" rx="28" fill="#1a1a1f"/>
  <text x="34" y="92" font-family="Inter, Helvetica, Arial, sans-serif" font-size="72" font-weight="700" fill="#ececef">d</text>
  <circle cx="86" cy="32" r="8" fill="#6c8cff"/>
</svg>`;
