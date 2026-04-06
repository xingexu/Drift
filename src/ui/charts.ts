// ---------------------------------------------------------------------------
// Drift – Pure SVG chart generators (no dependencies)
// ---------------------------------------------------------------------------

/**
 * Render a sparkline SVG from data points.
 */
export function renderSparkline(
  data: { label: string; value: number }[],
  width = 280,
  height = 64,
): string {
  if (data.length < 2) return "";

  const maxVal = Math.max(...data.map((d) => d.value), 1);
  const padding = 4;
  const w = width - padding * 2;
  const h = height - padding * 2;

  const points = data.map((d, i) => {
    const x = padding + (i / (data.length - 1)) * w;
    const y = padding + h - (d.value / maxVal) * h;
    return `${x},${y}`;
  });

  const polyline = points.join(" ");
  // Create filled area below the line
  const areaPoints = `${padding},${padding + h} ${polyline} ${padding + w},${padding + h}`;

  return `
    <svg class="sparkline" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" fill="none">
      <defs>
        <linearGradient id="spark-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="var(--color-accent)" stop-opacity="0.2"/>
          <stop offset="100%" stop-color="var(--color-accent)" stop-opacity="0"/>
        </linearGradient>
      </defs>
      <polygon points="${areaPoints}" fill="url(#spark-fill)"/>
      <polyline points="${polyline}" stroke="var(--color-accent)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sparkline-line"/>
      ${data.map((d, i) => {
        const x = padding + (i / (data.length - 1)) * w;
        const y = padding + h - (d.value / maxVal) * h;
        return `<circle cx="${x}" cy="${y}" r="3" fill="var(--color-accent)" class="sparkline-dot"/>`;
      }).join("")}
      ${data.map((d, i) => {
        const x = padding + (i / (data.length - 1)) * w;
        return `<text x="${x}" y="${height - 1}" text-anchor="middle" class="sparkline-label">${d.label}</text>`;
      }).join("")}
    </svg>
  `;
}

/**
 * Render a donut chart SVG from segments.
 */
export function renderDonut(
  segments: { value: number; color: string; label: string }[],
  size = 80,
): string {
  const total = segments.reduce((sum, s) => sum + s.value, 0);
  if (total === 0) return "";

  const cx = size / 2;
  const cy = size / 2;
  const radius = (size - 12) / 2;
  const circumference = 2 * Math.PI * radius;

  let offset = 0;
  const arcs = segments.map((seg) => {
    const pct = seg.value / total;
    const dash = circumference * pct;
    const gap = circumference - dash;
    const rotation = (offset / total) * 360 - 90;
    offset += seg.value;
    return `<circle cx="${cx}" cy="${cy}" r="${radius}" fill="none" stroke="${seg.color}" stroke-width="6"
      stroke-dasharray="${dash} ${gap}"
      transform="rotate(${rotation} ${cx} ${cy})"
      class="donut-segment"/>`;
  });

  // Center text showing biggest segment %
  const mainPct = total > 0 ? Math.round((segments[0].value / total) * 100) : 0;

  return `
    <svg class="donut-chart" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
      ${arcs.join("")}
      <text x="${cx}" y="${cy - 2}" text-anchor="middle" class="donut-pct">${mainPct}%</text>
      <text x="${cx}" y="${cy + 10}" text-anchor="middle" class="donut-label">${segments[0]?.label ?? ""}</text>
    </svg>
  `;
}

/**
 * Render a streak calendar (30-day grid of dots).
 */
export function renderStreakCalendar(
  history: { date: string; met: boolean }[],
  streak: number,
): string {
  const today = new Date();
  const days: { date: string; status: "met" | "missed" | "none" }[] = [];

  for (let i = 29; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().split("T")[0];
    const entry = history.find((h) => h.date === dateStr);
    days.push({
      date: dateStr,
      status: entry ? (entry.met ? "met" : "missed") : "none",
    });
  }

  const cols = 10;
  const rows = 3;
  const dotSize = 10;
  const gap = 4;
  const width = cols * (dotSize + gap) - gap;
  const height = rows * (dotSize + gap) - gap + 24; // extra for streak text

  return `
    <div class="streak-section">
      <div class="streak-header">
        <span class="streak-flame">${streak > 0 ? "🔥" : ""}</span>
        <span class="streak-count">${streak} day streak</span>
      </div>
      <svg class="streak-calendar" width="${width}" height="${rows * (dotSize + gap) - gap}" viewBox="0 0 ${width} ${rows * (dotSize + gap) - gap}">
        ${days.map((day, i) => {
          const col = Math.floor(i / rows);
          const row = i % rows;
          const x = col * (dotSize + gap);
          const y = row * (dotSize + gap);
          const fill = day.status === "met" ? "var(--color-productive)"
            : day.status === "missed" ? "var(--color-distraction)"
            : "var(--bg-surface)";
          return `<rect x="${x}" y="${y}" width="${dotSize}" height="${dotSize}" rx="2" fill="${fill}" class="streak-dot">
            <title>${day.date}: ${day.status}</title>
          </rect>`;
        }).join("")}
      </svg>
    </div>
  `;
}
