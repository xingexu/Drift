import React from "react";
import {
  AbsoluteFill,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from "remotion";
import { COLORS, FONTS } from "./styles";

/**
 * Drift — product walkthrough (32s @ 30fps = 960 frames).
 * A faithful recreation of the macOS app: real sidebar + tabs, an animated
 * cursor touring Home → Session → Focus → History → Settings, finishing on
 * the (now working) Typography control, then a CTA.
 */
export const DriftDemo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg, fontFamily: FONTS.display }}>
      <Sequence from={0} durationInFrames={72}>
        <LogoReveal />
      </Sequence>
      <Sequence from={72} durationInFrames={780}>
        <AppTour />
      </Sequence>
      <Sequence from={852} durationInFrames={108}>
        <CTAScene />
      </Sequence>
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 1 — Logo reveal                                              */
/* ------------------------------------------------------------------ */
const LogoReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame, fps, config: { damping: 12, mass: 0.8 } });
  const logoOpacity = interpolate(frame, [0, 18], [0, 1], { extrapolateRight: "clamp" });
  const textOpacity = interpolate(frame, [22, 42], [0, 1], { extrapolateRight: "clamp" });
  const textY = interpolate(frame, [22, 46], [26, 0], { extrapolateRight: "clamp" });
  const subOpacity = interpolate(frame, [38, 58], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [60, 72], [1, 0], { extrapolateLeft: "clamp" });
  const orbX = Math.sin(frame * 0.03) * 80;
  const orbY = Math.cos(frame * 0.02) * 60;

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        opacity: fadeOut,
        background: `radial-gradient(circle at 32% 38%, ${COLORS.drift}18, transparent 60%),
                     radial-gradient(circle at 70% 62%, ${COLORS.green}10, transparent 50%),
                     ${COLORS.bg}`,
      }}
    >
      <div
        style={{
          position: "absolute",
          width: 360,
          height: 360,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${COLORS.drift}22, transparent)`,
          transform: `translate(${orbX}px, ${orbY}px)`,
          filter: "blur(46px)",
        }}
      />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 26 }}>
        <Logo size={126} radius={30} fontSize={66} scale={logoScale} opacity={logoOpacity} />
        <h1
          style={{
            fontSize: 60,
            fontWeight: 800,
            color: COLORS.text,
            margin: 0,
            letterSpacing: -2,
            opacity: textOpacity,
            transform: `translateY(${textY}px)`,
          }}
        >
          Drift
        </h1>
        <p style={{ fontSize: 23, color: COLORS.textSecondary, margin: 0, opacity: subOpacity, letterSpacing: -0.3 }}>
          Know where your time goes
        </p>
      </div>
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 2 — App tour (window chrome + cursor + 5 screens)            */
/* ------------------------------------------------------------------ */

const TABS = [
  { key: "home", label: "Home", icon: "house", shortcut: "1" },
  { key: "session", label: "Session", icon: "chart", shortcut: "2" },
  { key: "focus", label: "Focus", icon: "timer", shortcut: "3" },
  { key: "history", label: "History", icon: "clock", shortcut: "4" },
  { key: "settings", label: "Settings", icon: "gear", shortcut: "5" },
];

// Phase start frames (relative to AppTour sequence)
const PHASES = [
  { key: "home", start: 0 },
  { key: "session", start: 150 },
  { key: "focus", start: 305 },
  { key: "history", start: 470 },
  { key: "settings", start: 625 },
];

const AppTour: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Window entrance
  const winScale = spring({ frame, fps, config: { damping: 16, mass: 0.9 } });
  const winOpacity = interpolate(frame, [0, 16], [0, 1], { extrapolateRight: "clamp" });
  const winY = interpolate(frame, [0, 20], [40, 0], { extrapolateRight: "clamp" });

  // Active phase
  let active = 0;
  for (let i = 0; i < PHASES.length; i++) if (frame >= PHASES[i].start) active = i;
  const activeKey = PHASES[active].key;
  const screenFrame = frame - PHASES[active].start;

  // Window geometry
  const W = 1480;
  const H = 904;
  const TITLE_H = 40;
  const SIDEBAR_W = 232;

  // Sidebar nav row geometry (window-local)
  const navTop = TITLE_H + 132; // titlebar + logo header + WORKSPACE label
  const rowH = 46;
  const navYof = (i: number) => navTop + i * rowH + rowH / 2;

  // Cursor keyframes (window-local coordinates)
  const cf = [0, 132, 150, 288, 305, 452, 470, 608, 625, 700, 742, 780];
  const cx = [120, 120, 120, 120, 120, 120, 120, 120, 120, 120, 980, 980];
  const cy = [
    navYof(0), navYof(0),
    navYof(1), navYof(1),
    navYof(2), navYof(2),
    navYof(3), navYof(3),
    navYof(4), navYof(4),
    640, 640,
  ];
  const curX = interpolate(frame, cf, cx, { extrapolateRight: "clamp" });
  const curY = interpolate(frame, cf, cy, { extrapolateRight: "clamp" });
  // Click pulse near each phase boundary + typography taps
  const clickAt = [150, 305, 470, 625, 690, 718, 742];
  let click = 0;
  for (const c of clickAt) {
    const d = frame - c;
    if (d >= 0 && d < 12) click = Math.max(click, Math.sin((d / 12) * Math.PI));
  }

  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", background: COLORS.bg }}>
      <div
        style={{
          position: "relative",
          width: W,
          height: H,
          transform: `translateY(${winY}px) scale(${winScale})`,
          opacity: winOpacity,
          borderRadius: 16,
          overflow: "hidden",
          background: COLORS.bg,
          border: `1px solid ${COLORS.hairline}`,
          boxShadow: "0 50px 130px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.04)",
        }}
      >
        {/* Title bar */}
        <div
          style={{
            height: TITLE_H,
            display: "flex",
            alignItems: "center",
            paddingLeft: 18,
            gap: 9,
            background: COLORS.navy,
            borderBottom: `1px solid ${COLORS.hairline}`,
          }}
        >
          <Dot color="#FF5F57" />
          <Dot color="#FEBC2E" />
          <Dot color="#28C840" />
        </div>

        <div style={{ display: "flex", height: H - TITLE_H }}>
          {/* Sidebar */}
          <Sidebar widthPx={SIDEBAR_W} activeKey={activeKey} />
          {/* Content */}
          <div style={{ flex: 1, position: "relative", background: COLORS.bg, overflow: "hidden" }}>
            <Topbar activeKey={activeKey} />
            <div style={{ position: "relative", height: H - TITLE_H - 56 }}>
              <Screen activeKey={activeKey} t={screenFrame} fps={fps} />
            </div>
          </div>
        </div>

        {/* Cursor */}
        <Cursor x={curX} y={curY} click={click} />
      </div>
    </AbsoluteFill>
  );
};

const Dot: React.FC<{ color: string }> = ({ color }) => (
  <div style={{ width: 12, height: 12, borderRadius: "50%", background: color }} />
);

const Cursor: React.FC<{ x: number; y: number; click: number }> = ({ x, y, click }) => (
  <div style={{ position: "absolute", left: x, top: y, transform: "translate(-3px,-2px)", zIndex: 50 }}>
    {click > 0 && (
      <div
        style={{
          position: "absolute",
          left: -18,
          top: -18,
          width: 40,
          height: 40,
          borderRadius: "50%",
          border: `2px solid ${COLORS.drift}`,
          opacity: 1 - click,
          transform: `scale(${0.4 + click * 1.1})`,
        }}
      />
    )}
    <svg width="26" height="32" viewBox="0 0 26 32" style={{ filter: "drop-shadow(0 3px 6px rgba(0,0,0,0.5))" }}>
      <path d="M2 2 L2 24 L8 18 L12 27 L16 25 L12 16 L20 16 Z" fill="white" stroke="rgba(0,0,0,0.5)" strokeWidth="1.2" />
    </svg>
  </div>
);

/* ----------------------------- Sidebar ---------------------------- */
const Sidebar: React.FC<{ widthPx: number; activeKey: string }> = ({ widthPx, activeKey }) => (
  <div style={{ width: widthPx, background: COLORS.navy, display: "flex", flexDirection: "column", padding: "0 0" }}>
    {/* Header */}
    <div style={{ height: 56, display: "flex", alignItems: "center", gap: 10, padding: "0 18px" }}>
      <Logo size={26} radius={8} fontSize={15} scale={1} opacity={1} />
      <span style={{ color: "white", fontWeight: 800, fontSize: 17, letterSpacing: -0.3 }}>Drift</span>
    </div>
    {/* Workspace label */}
    <div style={{ padding: "18px 20px 8px", color: "rgba(255,255,255,0.3)", fontSize: 11, fontWeight: 700, letterSpacing: 1.8 }}>
      WORKSPACE
    </div>
    {/* Nav */}
    <div style={{ padding: "0 12px", display: "flex", flexDirection: "column", gap: 4 }}>
      {TABS.map((t) => {
        const sel = t.key === activeKey;
        return (
          <div
            key={t.key}
            style={{
              position: "relative",
              height: 38,
              display: "flex",
              alignItems: "center",
              gap: 11,
              padding: "0 12px",
              borderRadius: 9,
              background: sel ? `${COLORS.drift}1F` : "transparent",
            }}
          >
            {sel && (
              <div style={{ position: "absolute", left: -6, top: 8, bottom: 8, width: 3, borderRadius: 2, background: COLORS.drift }} />
            )}
            <NavIcon name={t.icon} color={sel ? COLORS.drift : "rgba(255,255,255,0.4)"} />
            <span style={{ flex: 1, color: sel ? "white" : "rgba(255,255,255,0.58)", fontSize: 14.5, fontWeight: sel ? 700 : 500 }}>
              {t.label}
            </span>
            <span
              style={{
                fontSize: 11,
                fontFamily: FONTS.mono,
                color: sel ? `${COLORS.drift}AA` : "rgba(255,255,255,0.22)",
                background: "rgba(255,255,255,0.05)",
                border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: 4,
                padding: "1px 6px",
              }}
            >
              {t.shortcut}
            </span>
          </div>
        );
      })}
    </div>

    <div style={{ flex: 1 }} />

    {/* Pro CTA */}
    <div style={{ margin: "0 12px 12px", padding: 14, borderRadius: 11, background: "rgba(255,255,255,0.035)", border: "1px solid rgba(255,255,255,0.07)" }}>
      <div style={{ color: "rgba(255,255,255,0.88)", fontSize: 13.5, fontWeight: 700 }}>✦ Drift Pro</div>
      <div style={{ color: "rgba(255,255,255,0.4)", fontSize: 11.5, marginTop: 3 }}>Unlock advanced reports</div>
    </div>
    {/* User */}
    <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "12px 18px 20px" }}>
      <div style={{ width: 26, height: 26, borderRadius: "50%", background: `${COLORS.drift}30`, color: COLORS.drift, fontSize: 11, fontWeight: 800, display: "flex", alignItems: "center", justifyContent: "center" }}>DX</div>
      <div>
        <div style={{ color: "white", fontSize: 13, fontWeight: 600 }}>dahang</div>
        <div style={{ color: "rgba(255,255,255,0.4)", fontSize: 11 }}>Pro</div>
      </div>
    </div>
  </div>
);

const NavIcon: React.FC<{ name: string; color: string }> = ({ name, color }) => {
  const common = { width: 17, height: 17, viewBox: "0 0 24 24", fill: "none", stroke: color, strokeWidth: 2, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  switch (name) {
    case "house":
      return <svg {...common}><path d="M3 11l9-8 9 8" /><path d="M5 10v10h14V10" /></svg>;
    case "chart":
      return <svg {...common}><path d="M4 20V10M10 20V4M16 20v-7M22 20H2" /></svg>;
    case "timer":
      return <svg {...common}><circle cx="12" cy="13" r="8" /><path d="M12 13V9M9 2h6" /></svg>;
    case "clock":
      return <svg {...common}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>;
    case "gear":
      return <svg {...common}><circle cx="12" cy="12" r="3.2" /><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" /></svg>;
    default:
      return <svg {...common}><circle cx="12" cy="12" r="8" /></svg>;
  }
};

/* ----------------------------- Topbar ----------------------------- */
const TITLES: Record<string, string> = {
  home: "Today",
  session: "Live Session",
  focus: "Focus Mode",
  history: "History",
  settings: "Settings",
};
const Topbar: React.FC<{ activeKey: string }> = ({ activeKey }) => (
  <div
    style={{
      height: 56,
      display: "flex",
      alignItems: "center",
      padding: "0 26px",
      gap: 14,
      borderBottom: `1px solid ${COLORS.hairline}`,
      background: "rgba(255,255,255,0.015)",
    }}
  >
    <span style={{ color: COLORS.text, fontSize: 17, fontWeight: 700, letterSpacing: -0.3 }}>{TITLES[activeKey]}</span>
    <div style={{ display: "flex", alignItems: "center", gap: 7, padding: "5px 11px", borderRadius: 100, background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.07)" }}>
      <div style={{ width: 7, height: 7, borderRadius: "50%", background: COLORS.green, boxShadow: `0 0 8px ${COLORS.green}` }} />
      <span style={{ color: COLORS.textSecondary, fontSize: 12.5, fontWeight: 500 }}>Tracking</span>
    </div>
    <div style={{ flex: 1 }} />
    {["☾", "◔", "⚙"].map((g, i) => (
      <div key={i} style={{ width: 32, height: 32, borderRadius: 9, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)", display: "flex", alignItems: "center", justifyContent: "center", color: COLORS.textSecondary, fontSize: 14 }}>{g}</div>
    ))}
  </div>
);

/* ----------------------------- Screens ---------------------------- */
const Screen: React.FC<{ activeKey: string; t: number; fps: number }> = ({ activeKey, t, fps }) => {
  const enter = interpolate(t, [0, 16], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
  const y = interpolate(t, [0, 18], [16, 0], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
  return (
    <div style={{ position: "absolute", inset: 0, padding: 30, opacity: enter, transform: `translateY(${y}px)` }}>
      {activeKey === "home" && <HomeScreen t={t} fps={fps} />}
      {activeKey === "session" && <SessionScreen t={t} />}
      {activeKey === "focus" && <FocusScreen t={t} fps={fps} />}
      {activeKey === "history" && <HistoryScreen t={t} />}
      {activeKey === "settings" && <SettingsScreen t={t} />}
    </div>
  );
};

const Card: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({ children, style }) => (
  <div style={{ background: COLORS.surface, border: `1px solid ${COLORS.hairline}`, borderRadius: 16, padding: 22, ...style }}>{children}</div>
);

const SectionLabel: React.FC<{ children: React.ReactNode; color?: string }> = ({ children, color }) => (
  <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 1.6, textTransform: "uppercase", color: color || COLORS.textTertiary, marginBottom: 12 }}>{children}</div>
);

/* HOME */
const HomeScreen: React.FC<{ t: number; fps: number }> = ({ t, fps }) => {
  const pct = Math.round(interpolate(t, [10, 80], [0, 78], { extrapolateRight: "clamp", extrapolateLeft: "clamp" }));
  const C = 2 * Math.PI * 92;
  const off = C - (C * pct) / 100;
  const ringScale = spring({ frame: Math.max(0, t - 4), fps, config: { damping: 15, mass: 0.6 } });
  const stats = [
    { label: "DRIFT SCORE", value: "22%", color: COLORS.red },
    { label: "APPS USED", value: "5", color: COLORS.text },
    { label: "STREAK", value: "7d", color: COLORS.orange },
  ];
  return (
    <div style={{ display: "flex", gap: 22, height: "100%" }}>
      <Card style={{ width: 420, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
        <SectionLabel color={COLORS.drift}>Focus Rate · Today</SectionLabel>
        <div style={{ position: "relative", transform: `scale(${ringScale})`, marginTop: 8 }}>
          <svg width={240} height={240} viewBox="0 0 240 240">
            <circle cx={120} cy={120} r={92} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={12} />
            <circle cx={120} cy={120} r={92} fill="none" stroke={COLORS.drift} strokeWidth={12} strokeLinecap="round" strokeDasharray={C} strokeDashoffset={off} transform="rotate(-90 120 120)" style={{ filter: `drop-shadow(0 0 12px ${COLORS.drift}70)` }} />
          </svg>
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
            <span style={{ fontSize: 54, fontWeight: 800, color: COLORS.text, fontFamily: FONTS.mono }}>{pct}%</span>
            <span style={{ fontSize: 12, color: COLORS.textTertiary, fontWeight: 700, letterSpacing: 2 }}>FOCUS</span>
          </div>
        </div>
        <div style={{ marginTop: 14, color: COLORS.green, fontSize: 13, fontWeight: 600 }}>↑ 4% vs your average</div>
      </Card>

      <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 22 }}>
        <div style={{ display: "flex", gap: 16 }}>
          {stats.map((s, i) => {
            const o = interpolate(t, [20 + i * 10, 34 + i * 10], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
            return (
              <Card key={i} style={{ flex: 1, opacity: o }}>
                <div style={{ fontSize: 30, fontWeight: 800, color: s.color, fontFamily: FONTS.mono }}>{s.value}</div>
                <div style={{ fontSize: 11, color: COLORS.textTertiary, fontWeight: 700, letterSpacing: 1, marginTop: 6 }}>{s.label}</div>
              </Card>
            );
          })}
        </div>
        <Card style={{ flex: 1 }}>
          <SectionLabel>Today · Timeline</SectionLabel>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 5, height: 150, marginTop: 10 }}>
            {Array.from({ length: 32 }).map((_, i) => {
              const h = 24 + Math.abs(Math.sin(i * 0.7)) * 110;
              const grow = interpolate(t, [24 + i * 1.4, 40 + i * 1.4], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
              const c = i % 7 === 0 ? COLORS.red : i % 3 === 0 ? "rgba(255,255,255,0.18)" : COLORS.green;
              return <div key={i} style={{ flex: 1, height: h * grow, background: c, borderRadius: 3, opacity: 0.9 }} />;
            })}
          </div>
        </Card>
      </div>
    </div>
  );
};

/* SESSION */
const SessionScreen: React.FC<{ t: number }> = ({ t }) => {
  const apps = [
    { name: "Xcode", cat: "Productive", color: COLORS.green, time: "1h 42m", pct: 1 },
    { name: "Safari — Twitter", cat: "Distraction", color: COLORS.red, time: "38m", pct: 0.5 },
    { name: "Slack", cat: "Productive", color: COLORS.green, time: "1h 08m", pct: 0.72 },
    { name: "Spotify", cat: "Neutral", color: COLORS.textSecondary, time: "26m", pct: 0.33 },
    { name: "Terminal", cat: "Productive", color: COLORS.green, time: "51m", pct: 0.6 },
  ];
  return (
    <div style={{ display: "flex", gap: 22, height: "100%" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 22 }}>
        <Card>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
            <div style={{ width: 9, height: 9, borderRadius: "50%", background: COLORS.green, boxShadow: `0 0 10px ${COLORS.green}` }} />
            <span style={{ color: COLORS.green, fontSize: 12.5, fontWeight: 800, letterSpacing: 1.5 }}>LIVE</span>
            <div style={{ flex: 1 }} />
            <span style={{ fontSize: 34, fontWeight: 800, color: COLORS.text, fontFamily: FONTS.mono }}>01:24:36</span>
          </div>
          <SectionLabel>App Breakdown</SectionLabel>
          {apps.map((a, i) => {
            const o = interpolate(t, [10 + i * 12, 26 + i * 12], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
            const bar = interpolate(t, [16 + i * 12, 44 + i * 12], [0, a.pct], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
            return (
              <div key={i} style={{ opacity: o, marginBottom: 12 }}>
                <div style={{ display: "flex", alignItems: "center", marginBottom: 6 }}>
                  <div style={{ width: 8, height: 8, borderRadius: "50%", background: a.color, marginRight: 10 }} />
                  <span style={{ flex: 1, color: COLORS.text, fontSize: 15, fontWeight: 500 }}>{a.name}</span>
                  <span style={{ fontSize: 11, fontWeight: 700, color: a.color, background: `${a.color}1F`, padding: "3px 9px", borderRadius: 20, marginRight: 12 }}>{a.cat}</span>
                  <span style={{ fontSize: 12.5, color: COLORS.textTertiary, fontFamily: FONTS.mono, width: 62, textAlign: "right" }}>{a.time}</span>
                </div>
                <div style={{ height: 6, borderRadius: 3, background: "rgba(255,255,255,0.06)" }}>
                  <div style={{ height: 6, borderRadius: 3, width: `${bar * 100}%`, background: a.color }} />
                </div>
              </div>
            );
          })}
        </Card>
      </div>
      <Card style={{ width: 320 }}>
        <SectionLabel color={COLORS.drift}>Session Stats</SectionLabel>
        {[
          { k: "Productive", v: "3h 41m", c: COLORS.green },
          { k: "Distraction", v: "38m", c: COLORS.red },
          { k: "Switches", v: "47", c: COLORS.text },
          { k: "Focus rate", v: "78%", c: COLORS.drift },
        ].map((s, i) => {
          const o = interpolate(t, [24 + i * 10, 40 + i * 10], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
          return (
            <div key={i} style={{ opacity: o, display: "flex", justifyContent: "space-between", alignItems: "center", padding: "13px 0", borderBottom: i < 3 ? `1px solid ${COLORS.hairline}` : "none" }}>
              <span style={{ color: COLORS.textSecondary, fontSize: 14 }}>{s.k}</span>
              <span style={{ color: s.c, fontSize: 19, fontWeight: 800, fontFamily: FONTS.mono }}>{s.v}</span>
            </div>
          );
        })}
      </Card>
    </div>
  );
};

/* FOCUS */
const FocusScreen: React.FC<{ t: number; fps: number }> = ({ t, fps }) => {
  const C = 2 * Math.PI * 86;
  const prog = interpolate(t, [0, 120], [0.82, 0.7], { extrapolateRight: "clamp" });
  const off = C - C * prog;
  const ringScale = spring({ frame: Math.max(0, t - 6), fps, config: { damping: 13 } });
  const sites = ["twitter.com", "reddit.com", "youtube.com", "instagram.com", "tiktok.com"];
  return (
    <div style={{ display: "flex", gap: 22, height: "100%", alignItems: "stretch" }}>
      <Card style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
        <div style={{ position: "relative", transform: `scale(${ringScale})` }}>
          <svg width={236} height={236} viewBox="0 0 236 236">
            <circle cx={118} cy={118} r={86} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={10} />
            <circle cx={118} cy={118} r={86} fill="none" stroke={COLORS.drift} strokeWidth={10} strokeLinecap="round" strokeDasharray={C} strokeDashoffset={off} transform="rotate(-90 118 118)" style={{ filter: `drop-shadow(0 0 10px ${COLORS.drift}60)` }} />
          </svg>
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
            <span style={{ fontSize: 46, fontWeight: 800, color: COLORS.text, fontFamily: FONTS.mono }}>24:38</span>
            <span style={{ fontSize: 11, fontWeight: 800, color: COLORS.drift, letterSpacing: 3, marginTop: 4 }}>FOCUS</span>
          </div>
        </div>
        <div style={{ color: COLORS.textTertiary, fontSize: 13.5, marginTop: 18 }}>Session 3 of 4</div>
        <div style={{ marginTop: 20, padding: "12px 30px", borderRadius: 12, background: COLORS.drift, color: "#0B0D12", fontWeight: 800, fontSize: 15 }}>Pause</div>
      </Card>
      <Card style={{ width: 380 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 14 }}>
          <span style={{ fontSize: 16 }}>🛡</span>
          <SectionLabel color={COLORS.red}>Blocked Sites · Active</SectionLabel>
        </div>
        {sites.map((s, i) => {
          const o = interpolate(t, [14 + i * 12, 30 + i * 12], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
          return (
            <div key={i} style={{ opacity: o, display: "flex", alignItems: "center", padding: "11px 14px", borderRadius: 10, background: `${COLORS.red}12`, marginBottom: 7 }}>
              <span style={{ color: `${COLORS.red}`, marginRight: 11, fontWeight: 700 }}>✕</span>
              <span style={{ color: COLORS.textSecondary, fontSize: 14.5 }}>{s}</span>
            </div>
          );
        })}
        <div style={{ marginTop: 14, color: COLORS.textTertiary, fontSize: 12.5, lineHeight: 1.5 }}>
          🔒 Password lock prevents stopping early.
        </div>
      </Card>
    </div>
  );
};

/* HISTORY */
const HistoryScreen: React.FC<{ t: number }> = ({ t }) => {
  const periods = ["Today", "Week", "Month", "All"];
  const rows = [
    { date: "Today · 9:12 AM", dur: "2h 24m", focus: 78, apps: 5 },
    { date: "Yesterday · 2:40 PM", dur: "1h 50m", focus: 64, apps: 7 },
    { date: "Mon · 10:05 AM", dur: "3h 12m", focus: 82, apps: 4 },
    { date: "Sun · 8:30 PM", dur: "55m", focus: 41, apps: 9 },
    { date: "Sat · 11:20 AM", dur: "2h 02m", focus: 71, apps: 6 },
  ];
  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", gap: 18 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <div style={{ display: "flex", gap: 4, padding: 4, borderRadius: 11, background: "rgba(255,255,255,0.05)" }}>
          {periods.map((p, i) => (
            <div key={p} style={{ padding: "7px 18px", borderRadius: 8, fontSize: 13.5, fontWeight: 600, color: i === 1 ? COLORS.text : COLORS.textTertiary, background: i === 1 ? "rgba(255,255,255,0.10)" : "transparent" }}>{p}</div>
          ))}
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "9px 16px", borderRadius: 10, background: "rgba(255,255,255,0.04)", border: `1px solid ${COLORS.hairline}`, color: COLORS.textTertiary, fontSize: 13.5, width: 200 }}>🔍 Search sessions</div>
      </div>
      <Card style={{ flex: 1, padding: 0, overflow: "hidden" }}>
        {rows.map((r, i) => {
          const o = interpolate(t, [12 + i * 12, 28 + i * 12], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
          const x = interpolate(t, [12 + i * 12, 28 + i * 12], [30, 0], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
          const fc = r.focus >= 70 ? COLORS.green : r.focus >= 50 ? COLORS.orange : COLORS.red;
          return (
            <div key={i} style={{ opacity: o, transform: `translateX(${x}px)`, display: "flex", alignItems: "center", padding: "18px 22px", borderBottom: i < rows.length - 1 ? `1px solid ${COLORS.hairline}` : "none" }}>
              <div style={{ width: 38, height: 38, borderRadius: 10, background: `${fc}1C`, color: fc, display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 800, fontFamily: FONTS.mono, fontSize: 13, marginRight: 16 }}>{r.focus}</div>
              <div style={{ flex: 1 }}>
                <div style={{ color: COLORS.text, fontSize: 15, fontWeight: 600 }}>{r.date}</div>
                <div style={{ color: COLORS.textTertiary, fontSize: 12.5, marginTop: 3 }}>{r.apps} apps tracked</div>
              </div>
              <div style={{ color: COLORS.textSecondary, fontSize: 15, fontFamily: FONTS.mono, marginRight: 26 }}>{r.dur}</div>
              <div style={{ width: 120, height: 6, borderRadius: 3, background: "rgba(255,255,255,0.06)" }}>
                <div style={{ height: 6, borderRadius: 3, width: `${r.focus}%`, background: fc }} />
              </div>
            </div>
          );
        })}
      </Card>
    </div>
  );
};

/* SETTINGS — live Typography toggle (the fix) */
const SettingsScreen: React.FC<{ t: number }> = ({ t }) => {
  // Cycle the typography selection to show it actually changes the type.
  const typoOptions = ["Sora", "Serif", "Mono"];
  let typoIdx = 0;
  if (t >= 105) typoIdx = 2;
  else if (t >= 60) typoIdx = 1;
  const typoFamily = typoIdx === 1 ? 'Georgia, "Times New Roman", serif' : typoIdx === 2 ? FONTS.mono : FONTS.display;
  const calloutO = interpolate(t, [40, 58], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });

  const Segmented: React.FC<{ label: string; options: string[]; sel: number; highlight?: boolean }> = ({ label, options, sel, highlight }) => (
    <div style={{ marginBottom: 22 }}>
      <SectionLabel>{label}</SectionLabel>
      <div style={{ display: "flex", gap: 6, padding: 5, borderRadius: 12, background: "rgba(255,255,255,0.05)", position: "relative", border: highlight ? `1px solid ${COLORS.drift}66` : "1px solid transparent", boxShadow: highlight ? `0 0 0 3px ${COLORS.drift}22` : "none" }}>
        {options.map((o, i) => (
          <div key={o} style={{ flex: 1, textAlign: "center", padding: "9px 0", borderRadius: 8, fontSize: 14, fontWeight: 600, color: i === sel ? COLORS.text : COLORS.textTertiary, background: i === sel ? "rgba(255,255,255,0.12)" : "transparent", border: i === sel ? "1px solid rgba(255,255,255,0.12)" : "1px solid transparent" }}>{o}</div>
        ))}
      </div>
    </div>
  );

  return (
    <div style={{ display: "flex", gap: 22, height: "100%" }}>
      <Card style={{ flex: 1 }}>
        <SectionLabel color={COLORS.drift}>Appearance</SectionLabel>
        <Segmented label="Theme" options={["System", "Light", "Dark"]} sel={2} />
        <Segmented label="Density" options={["Compact", "Comfortable", "Spacious"]} sel={2} />
        <Segmented label="Typography" options={typoOptions} sel={typoIdx} highlight />
        <div style={{ marginTop: 6, opacity: calloutO, display: "inline-flex", alignItems: "center", gap: 8, padding: "8px 14px", borderRadius: 10, background: `${COLORS.green}1A`, border: `1px solid ${COLORS.green}55` }}>
          <span style={{ color: COLORS.green, fontWeight: 800 }}>✓</span>
          <span style={{ color: COLORS.green, fontSize: 13.5, fontWeight: 600 }}>Typography now changes the app live</span>
        </div>
      </Card>
      <Card style={{ width: 460, display: "flex", flexDirection: "column", justifyContent: "center" }}>
        <SectionLabel>Preview</SectionLabel>
        <div style={{ fontFamily: typoFamily }}>
          <div style={{ fontSize: 40, fontWeight: 800, color: COLORS.text, letterSpacing: -0.5 }}>Stay in flow.</div>
          <div style={{ fontSize: 17, color: COLORS.textSecondary, marginTop: 12, lineHeight: 1.6 }}>
            The quick brown fox jumps over the lazy dog — 1,234,567 focused minutes this week.
          </div>
          <div style={{ fontSize: 15, color: COLORS.drift, marginTop: 16, fontWeight: 600 }}>{typoOptions[typoIdx]} typeface</div>
        </div>
      </Card>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 3 — CTA                                                      */
/* ------------------------------------------------------------------ */
const CTAScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const scale = spring({ frame, fps, config: { damping: 12, mass: 0.6 } });
  const textO = interpolate(frame, [8, 30], [0, 1], { extrapolateRight: "clamp" });
  const btnO = interpolate(frame, [30, 50], [0, 1], { extrapolateRight: "clamp" });
  const btnY = interpolate(frame, [30, 50], [18, 0], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", background: `radial-gradient(circle at 50% 42%, ${COLORS.drift}14, ${COLORS.bg})` }}>
      <div style={{ textAlign: "center", transform: `scale(${scale})` }}>
        <Logo size={92} radius={22} fontSize={48} scale={1} opacity={1} />
        <h1 style={{ fontSize: 54, fontWeight: 800, color: COLORS.text, margin: "30px 0 0", letterSpacing: -2, opacity: textO }}>Take control of your focus.</h1>
        <p style={{ fontSize: 20, color: COLORS.textSecondary, marginTop: 14, opacity: textO }}>Free for macOS · No account required</p>
        <div style={{ marginTop: 38, opacity: btnO, transform: `translateY(${btnY}px)` }}>
          <span style={{ display: "inline-block", padding: "16px 50px", borderRadius: 14, background: `linear-gradient(135deg, ${COLORS.drift}, ${COLORS.driftDark})`, fontSize: 18, fontWeight: 800, color: "#0B0D12", boxShadow: `0 12px 40px ${COLORS.drift}40` }}>Download Drift</span>
        </div>
        <p style={{ fontSize: 13.5, color: COLORS.textTertiary, marginTop: 20, opacity: btnO }}>Works offline · Native macOS · Privacy first</p>
      </div>
    </AbsoluteFill>
  );
};

/* ----------------------------- Shared ----------------------------- */
const Logo: React.FC<{ size: number; radius: number; fontSize: number; scale: number; opacity: number }> = ({ size, radius, fontSize, scale, opacity }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: radius,
      background: `linear-gradient(135deg, ${COLORS.drift}, ${COLORS.driftDark})`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      transform: `scale(${scale})`,
      opacity,
      boxShadow: `0 16px 44px ${COLORS.drift}40`,
      margin: "0 auto",
    }}
  >
    <span style={{ fontSize, fontWeight: 800, color: "#0B0D12" }}>D</span>
  </div>
);
