import React from "react";
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const COLORS = {
  canvas: "#111016",
  cocoa: "#241A16",
  cocoaRaised: "#30231D",
  cream: "#FFF3DF",
  creamMuted: "#B8A99D",
  sand: "#E8C7A7",
  sandInk: "#241A16",
  productive: "#52A96B",
  distraction: "#E66C5C",
  focusBlue: "#7896FF",
  neutral: "#98939A",
  shell: "#080715",
  line: "rgba(255,243,223,0.15)",
};

const FONTS = {
  body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif',
  mono: '"SF Mono", Menlo, ui-monospace, monospace',
  pixel: '"Press Start 2P", "SF Mono", monospace',
};

const APP_WIDTH = 1500;
const APP_HEIGHT = 900;
const TITLEBAR_HEIGHT = 38;
const SIDEBAR_WIDTH = 220;
const TOOLBAR_HEIGHT = 54;

type TabKey = "today" | "focus" | "history" | "settings";
type PhaseKey = TabKey | "blocked";

const TABS: Array<{ key: TabKey; label: string; icon: "sun" | "scope" | "history" | "gear" }> = [
  { key: "today", label: "Today", icon: "sun" },
  { key: "focus", label: "Focus", icon: "scope" },
  { key: "history", label: "History", icon: "history" },
  { key: "settings", label: "Settings", icon: "gear" },
];

const PHASES: Array<{ key: PhaseKey; start: number }> = [
  { key: "today", start: 0 },
  { key: "focus", start: 165 },
  { key: "blocked", start: 355 },
  { key: "history", start: 500 },
  { key: "settings", start: 640 },
];

const fontFace =
  "@font-face{font-family:'Press Start 2P';src:url('" +
  staticFile("drift-current/PressStart2P.ttf") +
  "') format('truetype');font-display:swap;}";

export const DriftDemo: React.FC = () => {
  return (
    <AbsoluteFill
style={{ backgroundColor: COLORS.canvas, fontFamily: FONTS.body }}
from={-27}>
      <style>{fontFace}</style>
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
const LogoReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const scale = spring({ frame, fps, config: { damping: 14, mass: 0.8 } });
  const opacity = interpolate(frame, [0, 16], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const textOpacity = interpolate(frame, [18, 38], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const textY = interpolate(frame, [18, 42], [16, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(frame, [60, 72], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ opacity: fadeOut, backgroundColor: COLORS.canvas }}>
      <PixelBackdrop name="tracking" wash={0.48} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "column",
        }}
      >
        <Img
          src={staticFile("drift-current/logo.png")}
          style={{
            width: 132,
            height: 132,
            imageRendering: "pixelated",
            transform: "scale(" + scale + ")",
            opacity,
            filter: "drop-shadow(10px 12px 0 rgba(5,3,12,0.45))",
          }}
        />
        <h1
          style={{
            margin: "34px 0 0",
            color: COLORS.cream,
            fontFamily: FONTS.pixel,
            fontSize: 54,
            fontWeight: 400,
            letterSpacing: -2,
            opacity: textOpacity,
            transform: "translateY(" + textY + "px)",
            textShadow: "0 6px 0 rgba(142,56,47,0.9), 0 12px 0 rgba(36,26,22,0.85)",
          }}
        >
          DRIFT
        </h1>
        <p
          style={{
            margin: "24px 0 0",
            color: COLORS.creamMuted,
            fontSize: 20,
            opacity: textOpacity,
            transform: "translateY(" + textY + "px)",
          }}
        >
          Private focus tracking, built for your Mac.
        </p>
      </div>
    </AbsoluteFill>
  );
};

const AppTour: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const windowScale = spring({ frame, fps, config: { damping: 17, mass: 0.9 } });
  const windowOpacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const windowY = interpolate(frame, [0, 20], [34, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  let phaseIndex = 0;
  for (let i = 0; i < PHASES.length; i += 1) {
    if (frame >= PHASES[i].start) phaseIndex = i;
  }
  const phase = PHASES[phaseIndex];
  const phaseFrame = frame - phase.start;
  const activeTab: TabKey = phase.key === "blocked" ? "focus" : phase.key;

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        background: "linear-gradient(180deg,#090817 0%,#151020 100%)",
      }}
    >
      <div
        style={{
          position: "relative",
          width: APP_WIDTH,
          height: APP_HEIGHT,
          opacity: windowOpacity,
          transform: "translateY(" + windowY + "px) scale(" + windowScale + ")",
        }}
      >
        {phase.key === "blocked" ? (
          <BlockedBrowser t={phaseFrame} />
        ) : (
          <AppWindow activeTab={activeTab} t={phaseFrame} fps={fps} />
        )}
        {phase.key !== "blocked" && (
          <TourCursor phase={phase.key} t={phaseFrame} />
        )}
      </div>
    </AbsoluteFill>
  );
};

const AppWindow: React.FC<{ activeTab: TabKey; t: number; fps: number }> = ({
  activeTab,
  t,
  fps,
}) => {
  const backdrop =
    activeTab === "focus"
      ? "focus"
      : activeTab === "settings"
        ? "settings"
        : "tracking";
  const wash =
    activeTab === "focus"
      ? "rgba(5,3,14,0.34)"
      : "rgba(5,3,14,0.38)";

  return (
    <div style={windowFrameStyle}>
      <PixelBackdrop name={backdrop} wash={0} />
      <div style={{ position: "absolute", inset: 0, background: wash }} />
      <MacTitlebar />
      <Sidebar activeTab={activeTab} />
      <div
        style={{
          position: "absolute",
          top: TITLEBAR_HEIGHT,
          right: 0,
          bottom: 0,
          left: SIDEBAR_WIDTH,
        }}
      >
        <Toolbar />
        <div
          style={{
            position: "absolute",
            top: TOOLBAR_HEIGHT,
            right: 0,
            bottom: 0,
            left: 0,
            overflow: "hidden",
          }}
        >
          <CurrentScreen activeTab={activeTab} t={t} fps={fps} />
        </div>
      </div>
    </div>
  );
};

const windowFrameStyle: React.CSSProperties = {
  position: "relative",
  width: APP_WIDTH,
  height: APP_HEIGHT,
  overflow: "hidden",
  borderRadius: 18,
  background: COLORS.canvas,
  border: "1px solid rgba(255,243,223,0.16)",
  boxShadow:
    "0 52px 130px rgba(2,1,8,0.66),0 0 0 1px rgba(255,255,255,0.025)",
};

const PixelBackdrop: React.FC<{ name: "tracking" | "focus" | "settings"; wash: number }> = ({
  name,
  wash,
}) => (
  <>
    <Img
      src={staticFile("drift-current/" + name + ".png")}
      style={{
        position: "absolute",
        inset: 0,
        width: "100%",
        height: "100%",
        objectFit: "cover",
        imageRendering: "pixelated",
      }}
    />
    {wash > 0 && (
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "rgba(5,3,14," + wash + ")",
        }}
      />
    )}
  </>
);

const MacTitlebar: React.FC = () => (
  <div
    style={{
      position: "absolute",
      top: 0,
      right: 0,
      left: 0,
      height: TITLEBAR_HEIGHT,
      zIndex: 8,
      display: "flex",
      alignItems: "center",
      gap: 8,
      paddingLeft: 15,
      background: "rgba(8,7,21,0.88)",
      borderBottom: "1px solid rgba(255,243,223,0.11)",
    }}
  >
    <TrafficDot color="#FF5F57" />
    <TrafficDot color="#FEBC2E" />
    <TrafficDot color="#28C840" />
  </div>
);

const TrafficDot: React.FC<{ color: string }> = ({ color }) => (
  <div style={{ width: 11, height: 11, borderRadius: "50%", background: color }} />
);

const Sidebar: React.FC<{ activeTab: TabKey }> = ({ activeTab }) => (
  <div
    style={{
      position: "absolute",
      top: TITLEBAR_HEIGHT,
      bottom: 0,
      left: 0,
      zIndex: 5,
      width: SIDEBAR_WIDTH,
      background: "rgba(8,7,21,0.82)",
      borderRight: "1px solid rgba(255,243,223,0.13)",
    }}
  >
    <div
      style={{
        height: 108,
        display: "flex",
        alignItems: "center",
        gap: 12,
        padding: "22px 20px 12px",
      }}
    >
      <Img
  src={staticFile("drift-current/logo.png")}
  style={{ width: 42, height: 42, imageRendering: "pixelated" }}
  from={-14} />
      <span
        style={{
          color: COLORS.cream,
          fontFamily: FONTS.pixel,
          fontSize: 19,
          letterSpacing: -1,
        }}
      >
        Drift
      </span>
    </div>
    <div style={{ display: "flex", flexDirection: "column", gap: 8, padding: "8px 16px" }}>
      {TABS.map((tab) => {
        const selected = tab.key === activeTab;
        return (
          <div
            key={tab.key}
            style={{
              position: "relative",
              height: 46,
              display: "flex",
              alignItems: "center",
              gap: 12,
              padding: "0 14px",
              borderRadius: 12,
              color: selected ? COLORS.cream : COLORS.creamMuted,
              background: selected ? "rgba(232,199,167,0.16)" : "transparent",
            }}
          >
            {selected && (
              <div
                style={{
                  position: "absolute",
                  left: 0,
                  top: 10,
                  bottom: 10,
                  width: 3,
                  borderRadius: 99,
                  background: COLORS.sand,
                }}
              />
            )}
            <NavIcon name={tab.icon} color={selected ? COLORS.sand : COLORS.creamMuted} />
            <span style={{ fontSize: 14, fontWeight: selected ? 650 : 500 }}>{tab.label}</span>
          </div>
        );
      })}
    </div>
  </div>
);

const NavIcon: React.FC<{
  name: "sun" | "scope" | "history" | "gear";
  color: string;
}> = ({ name, color }) => {
  const common = {
    width: 18,
    height: 18,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: color,
    strokeWidth: 2,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  if (name === "sun") {
    return (
      <svg {...common}>
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </svg>
    );
  }
  if (name === "scope") {
    return (
      <svg {...common}>
        <circle cx="12" cy="12" r="7" />
        <circle cx="12" cy="12" r="2" />
        <path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
      </svg>
    );
  }
  if (name === "history") {
    return (
      <svg {...common}>
        <path d="M3 12a9 9 0 1 0 3-6.7L3 8" />
        <path d="M3 3v5h5M12 7v5l3 2" />
      </svg>
    );
  }
  return (
    <svg {...common}>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" />
    </svg>
  );
};

const Toolbar: React.FC = () => (
  <div
    style={{
      height: TOOLBAR_HEIGHT,
      display: "flex",
      alignItems: "center",
      gap: 10,
      padding: "0 32px",
      background: "rgba(8,7,21,0.67)",
      borderBottom: "1px solid rgba(255,243,223,0.12)",
      color: COLORS.creamMuted,
      fontSize: 12,
    }}
  >
    <span style={{ fontSize: 14, color: COLORS.sand }}>▣</span>
    <span>Thursday, August 27</span>
  </div>
);

const CurrentScreen: React.FC<{ activeTab: TabKey; t: number; fps: number }> = ({
  activeTab,
  t,
  fps,
}) => {
  const opacity = interpolate(t, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const y = interpolate(t, [0, 14], [8, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        opacity,
        transform: "translateY(" + y + "px)",
      }}
    >
      {activeTab === "today" && <TodayScreen t={t} />}
      {activeTab === "focus" && <FocusScreen t={t} fps={fps} />}
      {activeTab === "history" && <HistoryScreen t={t} />}
      {activeTab === "settings" && <SettingsScreen t={t} />}
    </div>
  );
};

const ContentSurface: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
  dense?: boolean;
}> = ({ children, style, dense = false }) => (
  <div
    style={{
      background: dense ? "rgba(17,16,22,0.88)" : "rgba(36,26,22,0.90)",
      border: "1px solid " + COLORS.line,
      borderRadius: 16,
      boxShadow: "0 14px 34px rgba(4,2,10,0.20)",
      ...style,
    }}
  >
    {children}
  </div>
);

const SectionLabel: React.FC<{ children: React.ReactNode; color?: string }> = ({
  children,
  color,
}) => (
  <div
    style={{
      color: color || COLORS.creamMuted,
      fontSize: 10,
      fontWeight: 750,
      letterSpacing: 0.7,
      textTransform: "uppercase",
    }}
  >
    {children}
  </div>
);

const TodayScreen: React.FC<{ t: number }> = ({ t }) => {
  const activities = [
    { app: "Xcode", detail: "Drift · FocusBlocker.swift", time: "42m", color: COLORS.productive },
    { app: "Safari", detail: "Apple Developer Documentation", time: "18m", color: COLORS.productive },
    { app: "Slack", detail: "Design review", time: "9m", color: COLORS.neutral },
  ];
  return (
    <div style={{ padding: "26px 32px 34px", height: "100%" }}>
      <div
        style={{
          minHeight: 126,
          display: "flex",
          alignItems: "center",
          padding: "0 4px",
        }}
      >
        <div>
          <div style={{ color: COLORS.creamMuted, fontSize: 12 }}>Today · Thursday</div>
          <h2
            style={{
              margin: "12px 0 0",
              color: COLORS.cream,
              fontFamily: FONTS.pixel,
              fontSize: 24,
              fontWeight: 400,
              letterSpacing: -1,
            }}
          >
            Your attention is settling in.
          </h2>
          <div style={{ marginTop: 12, color: "rgba(255,243,223,0.78)", fontSize: 14 }}>
            3h 46m focused across 6 applications.
          </div>
        </div>
        <div style={{ flex: 1 }} />
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 10,
            height: 44,
            padding: "0 18px",
            borderRadius: 999,
            background: "rgba(17,16,22,0.62)",
            border: "1px solid " + COLORS.line,
            color: COLORS.cream,
          }}
        >
          <span style={{ fontFamily: FONTS.mono, fontWeight: 800 }}>78</span>
          <span style={{ color: COLORS.creamMuted, fontSize: 12 }}>Focus quality</span>
          <span style={{ color: COLORS.sand }}>ⓘ</span>
        </div>
      </div>

      <ContentSurface
        style={{
          minHeight: 82,
          display: "flex",
          alignItems: "center",
          gap: 16,
          padding: "0 22px",
        }}
      >
        <div
          style={{
            width: 42,
            height: 42,
            display: "grid",
            placeItems: "center",
            background: "rgba(82,169,107,0.12)",
            border: "1px solid rgba(82,169,107,0.28)",
            color: COLORS.productive,
            fontWeight: 800,
          }}
        >
          X
        </div>
        <div>
          <SectionLabel>Current activity</SectionLabel>
          <div style={{ marginTop: 5, color: COLORS.cream, fontSize: 14, fontWeight: 650 }}>Xcode</div>
          <div style={{ marginTop: 3, color: COLORS.creamMuted, fontSize: 11 }}>Drift · FocusBlocker.swift</div>
        </div>
        <div style={{ flex: 1 }} />
        <span style={{ color: COLORS.creamMuted, fontFamily: FONTS.mono, fontSize: 12 }}>42m</span>
        <StatusTag text="Productive" color={COLORS.productive} />
        <Pill text="Stop tracking" />
      </ContentSurface>

      <ContentSurface
        style={{
          height: 82,
          display: "flex",
          marginTop: 16,
          overflow: "hidden",
        }}
      >
        {[
          ["Focused", "3h 46m", COLORS.productive],
          ["Distracted", "24m", COLORS.distraction],
          ["Switches", "21", COLORS.sand],
          ["Longest run", "1h 18m", COLORS.focusBlue],
        ].map((item, index) => (
          <div
            key={String(item[0])}
            style={{
              flex: 1,
              padding: "17px 20px",
              borderRight: index < 3 ? "1px solid " + COLORS.line : "none",
            }}
          >
            <SectionLabel>{item[0]}</SectionLabel>
            <div
              style={{
                marginTop: 8,
                color: String(item[2]),
                fontFamily: FONTS.mono,
                fontSize: 18,
                fontWeight: 750,
              }}
            >
              {item[1]}
            </div>
          </div>
        ))}
      </ContentSurface>

      <div style={{ display: "flex", gap: 16, marginTop: 16 }}>
        <ContentSurface style={{ flex: 1, overflow: "hidden" }}>
          <PanelHeader title="Recent activity" />
          {activities.map((activity, index) => {
            const opacity = interpolate(t, [18 + index * 9, 30 + index * 9], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            return (
              <div
                key={activity.app}
                style={{
                  opacity,
                  display: "flex",
                  alignItems: "center",
                  gap: 12,
                  height: 56,
                  padding: "0 18px",
                  borderTop: "1px solid " + COLORS.line,
                }}
              >
                <span style={{ width: 7, height: 7, background: activity.color }} />
                <div style={{ flex: 1 }}>
                  <div style={{ color: COLORS.cream, fontSize: 13, fontWeight: 600 }}>{activity.app}</div>
                  <div style={{ marginTop: 3, color: COLORS.creamMuted, fontSize: 10 }}>{activity.detail}</div>
                </div>
                <span style={{ color: COLORS.creamMuted, fontFamily: FONTS.mono, fontSize: 11 }}>{activity.time}</span>
              </div>
            );
          })}
        </ContentSurface>
        <ContentSurface style={{ width: 365, overflow: "hidden" }}>
          <PanelHeader title="Applications" />
          {[
            ["Xcode", "2h 04m", 0.92, COLORS.productive],
            ["Safari", "58m", 0.58, COLORS.productive],
            ["Slack", "31m", 0.34, COLORS.neutral],
          ].map((row) => (
            <div key={String(row[0])} style={{ padding: "12px 18px", borderTop: "1px solid " + COLORS.line }}>
              <div style={{ display: "flex", color: COLORS.cream, fontSize: 12 }}>
                <span style={{ flex: 1 }}>{row[0]}</span>
                <span style={{ color: COLORS.creamMuted, fontFamily: FONTS.mono, fontSize: 10 }}>{row[1]}</span>
              </div>
              <div style={{ height: 4, marginTop: 8, background: "rgba(255,243,223,0.08)" }}>
                <div style={{ width: Number(row[2]) * 100 + "%", height: 4, background: String(row[3]) }} />
              </div>
            </div>
          ))}
        </ContentSurface>
      </div>
    </div>
  );
};

const FocusScreen: React.FC<{ t: number; fps: number }> = ({ t, fps }) => {
  if (t < 78) return <FocusSetup t={t} />;
  return <ActiveFocus t={t - 78} fps={fps} />;
};

const FocusSetup: React.FC<{ t: number }> = ({ t }) => (
  <div style={{ padding: "30px 32px", height: "100%" }}>
    <h2
      style={{
        margin: 0,
        color: COLORS.cream,
        fontFamily: FONTS.pixel,
        fontSize: 24,
        fontWeight: 400,
      }}
    >
      Focus
    </h2>
    <p style={{ margin: "13px 0 26px", color: COLORS.creamMuted, fontSize: 14 }}>
      Choose one thing. Drift will keep the rest quiet.
    </p>
    <ContentSurface style={{ width: 680, padding: 28 }}>
      <SectionLabel>What do you want to finish?</SectionLabel>
      <div
        style={{
          height: 46,
          display: "flex",
          alignItems: "center",
          marginTop: 10,
          padding: "0 14px",
          borderRadius: 12,
          background: "rgba(17,16,22,0.74)",
          border: "1px solid " + COLORS.line,
          color: COLORS.cream,
          fontSize: 14,
        }}
      >
        Finish the launch narrative
        <span
          style={{
            width: 1,
            height: 18,
            marginLeft: 3,
            background: COLORS.sand,
            opacity: Math.floor(t / 10) % 2 === 0 ? 1 : 0,
          }}
        />
      </div>
      <div style={{ marginTop: 22 }}>
        <SectionLabel>Focus duration</SectionLabel>
        <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
          {["25m", "45m", "60m"].map((duration, index) => (
            <div
              key={duration}
              style={{
                minWidth: 86,
                height: 36,
                display: "grid",
                placeItems: "center",
                borderRadius: 999,
                background: index === 0 ? COLORS.sand : "rgba(17,16,22,0.58)",
                border: "1px solid " + (index === 0 ? COLORS.sand : COLORS.line),
                color: index === 0 ? COLORS.sandInk : COLORS.creamMuted,
                fontSize: 12,
                fontWeight: 700,
              }}
            >
              {duration}
            </div>
          ))}
        </div>
      </div>
      <div
        style={{
          marginTop: 22,
          borderRadius: 12,
          overflow: "hidden",
          border: "1px solid " + COLORS.line,
          background: "rgba(17,16,22,0.56)",
        }}
      >
        <SettingRow title="Add a break" detail="Choose a short reset after this focus block." on={false} />
        <SettingRow title="Block 11 distracting sites" detail="Keep the sites in your blocking list quiet." on />
        <div style={{ height: 50, display: "flex", alignItems: "center", padding: "0 16px", color: COLORS.cream, fontSize: 12 }}>
          <span style={{ color: COLORS.sand, marginRight: 10 }}>☷</span>
          Customize
          <span style={{ flex: 1 }} />
          <span style={{ color: COLORS.creamMuted }}>›</span>
        </div>
      </div>
      <div
        style={{
          height: 46,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 9,
          marginTop: 22,
          borderRadius: 999,
          background: COLORS.sand,
          color: COLORS.sandInk,
          fontSize: 13,
          fontWeight: 750,
          boxShadow: "0 8px 24px rgba(7,4,13,0.28)",
        }}
      >
        <span>▶</span>
        Begin 25-minute focus
      </div>
    </ContentSurface>
  </div>
);

const SettingRow: React.FC<{ title: string; detail: string; on: boolean }> = ({
  title,
  detail,
  on,
}) => (
  <div
    style={{
      minHeight: 62,
      display: "flex",
      alignItems: "center",
      padding: "0 16px",
      borderBottom: "1px solid " + COLORS.line,
    }}
  >
    <div>
      <div style={{ color: COLORS.cream, fontSize: 12, fontWeight: 600 }}>{title}</div>
      <div style={{ marginTop: 4, color: COLORS.creamMuted, fontSize: 10 }}>{detail}</div>
    </div>
    <div style={{ flex: 1 }} />
    <Toggle on={on} />
  </div>
);

const ActiveFocus: React.FC<{ t: number; fps: number }> = ({ t, fps }) => {
  const timerScale = spring({ frame: t, fps, config: { damping: 16, mass: 0.8 } });
  const seconds = Math.max(0, 38 - Math.floor(t / fps));
  const timer = "24:" + String(seconds).padStart(2, "0");
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
        paddingBottom: 92,
      }}
    >
      <div style={{ color: "rgba(255,243,223,0.82)", fontSize: 14, fontWeight: 650 }}>
        Finish the launch narrative
      </div>
      <div
        style={{
          marginTop: 22,
          color: COLORS.cream,
          fontFamily: FONTS.pixel,
          fontSize: 66,
          transform: "scale(" + timerScale + ")",
          textShadow: "0 6px 0 rgba(36,26,22,0.74)",
        }}
      >
        {timer}
      </div>
      <div style={{ marginTop: 18, color: COLORS.creamMuted, fontFamily: FONTS.mono, fontSize: 12 }}>
        22s focused
      </div>
      <div style={{ display: "flex", gap: 12, marginTop: 24 }}>
        <Pill text="Pause" />
        <Pill text="Finish" />
        <Pill text="Blocking 11 sites" accent />
      </div>
      <div
        style={{
          position: "absolute",
          right: 90,
          bottom: 70,
          left: 90,
          height: 3,
          background: "rgba(255,243,223,0.18)",
        }}
      >
        <div style={{ width: "23%", height: 3, background: COLORS.sand }} />
        <div
          style={{
            position: "absolute",
            left: "23%",
            bottom: 5,
            width: 18,
            height: 26,
            background: COLORS.cream,
            boxShadow: "4px 4px 0 rgba(7,4,13,0.45)",
          }}
        />
        <div
          style={{
            position: "absolute",
            left: "64%",
            bottom: 3,
            width: 7,
            height: 30,
            background: COLORS.productive,
            boxShadow: "-6px 7px 0 " + COLORS.productive + ",7px 10px 0 " + COLORS.productive,
          }}
        />
      </div>
    </div>
  );
};

const HistoryScreen: React.FC<{ t: number }> = ({ t }) => {
  const bars = [32, 50, 44, 68, 58, 78, 66];
  return (
    <div style={{ height: "100%" }}>
      <div
        style={{
          height: 134,
          display: "flex",
          alignItems: "center",
          padding: "0 32px",
        }}
      >
        <div>
          <h2 style={screenTitleStyle}>History</h2>
          <p style={screenSubtitleStyle}>A quieter record of where your attention went.</p>
        </div>
        <div style={{ flex: 1 }} />
        <Segmented options={["Today", "7 Days", "30 Days"]} selected={1} />
      </div>
      <div style={{ padding: "0 32px 30px" }}>
        <ContentSurface style={{ height: 82, display: "flex", overflow: "hidden" }}>
          {[
            ["Focused time", "18h 42m", COLORS.productive],
            ["Distraction", "2h 18m", COLORS.distraction],
            ["Switches / hour", "7.4", COLORS.sand],
            ["Longest run", "1h 38m", COLORS.focusBlue],
          ].map((item, index) => (
            <div
              key={String(item[0])}
              style={{
                flex: 1,
                padding: "16px 18px",
                borderRight: index < 3 ? "1px solid " + COLORS.line : "none",
              }}
            >
              <SectionLabel>{item[0]}</SectionLabel>
              <div style={{ marginTop: 8, color: String(item[2]), fontFamily: FONTS.mono, fontSize: 17, fontWeight: 750 }}>
                {item[1]}
              </div>
            </div>
          ))}
        </ContentSurface>
        <div style={{ display: "flex", gap: 16, marginTop: 16 }}>
          <ContentSurface style={{ flex: 1, height: 248, padding: 20 }}>
            <div style={{ display: "flex" }}>
              <SectionLabel>Daily attention</SectionLabel>
              <div style={{ flex: 1 }} />
              <span style={{ color: COLORS.creamMuted, fontSize: 10 }}>7 recorded days</span>
            </div>
            <div style={{ height: 174, display: "flex", alignItems: "flex-end", gap: 15, marginTop: 20 }}>
              {bars.map((height, index) => {
                const grow = interpolate(t, [10 + index * 4, 28 + index * 4], [0, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                });
                return (
                  <div key={index} style={{ flex: 1, display: "flex", alignItems: "flex-end", gap: 2, height: "100%" }}>
                    <div style={{ flex: 1, height: height * 1.7 * grow, background: COLORS.productive }} />
                    <div style={{ flex: 0.55, height: height * 0.55 * grow, background: COLORS.neutral }} />
                    <div style={{ flex: 0.42, height: height * 0.35 * grow, background: COLORS.distraction }} />
                  </div>
                );
              })}
            </div>
          </ContentSurface>
          <ContentSurface style={{ width: 405, overflow: "hidden" }}>
            <PanelHeader title="Sessions" />
            {[
              ["Today · 9:12 AM", "2h 24m", "78"],
              ["Wednesday · 2:40 PM", "1h 50m", "64"],
              ["Tuesday · 10:05 AM", "3h 12m", "82"],
            ].map((row) => (
              <div
                key={row[0]}
                style={{
                  height: 64,
                  display: "flex",
                  alignItems: "center",
                  gap: 12,
                  padding: "0 16px",
                  borderTop: "1px solid " + COLORS.line,
                }}
              >
                <span
                  style={{
                    width: 34,
                    height: 34,
                    display: "grid",
                    placeItems: "center",
                    background: "rgba(82,169,107,0.11)",
                    color: COLORS.productive,
                    fontFamily: FONTS.mono,
                    fontSize: 10,
                    fontWeight: 800,
                  }}
                >
                  {row[2]}
                </span>
                <span style={{ flex: 1, color: COLORS.cream, fontSize: 11 }}>{row[0]}</span>
                <span style={{ color: COLORS.creamMuted, fontFamily: FONTS.mono, fontSize: 10 }}>{row[1]}</span>
              </div>
            ))}
          </ContentSurface>
        </div>
      </div>
    </div>
  );
};

const SettingsScreen: React.FC<{ t: number }> = ({ t }) => {
  const sites = ["reddit.com", "youtube.com", "twitter.com", "instagram.com"];
  return (
    <div style={{ height: "100%" }}>
      <div style={{ height: 134, display: "flex", alignItems: "center", padding: "0 32px" }}>
        <div>
          <h2 style={screenTitleStyle}>Settings</h2>
          <p style={screenSubtitleStyle}>Tracking, focus, and privacy preferences.</p>
        </div>
      </div>
      <div style={{ display: "flex", gap: 24, padding: "0 32px 28px" }}>
        <ContentSurface style={{ width: 210, padding: 8 }}>
          {["General", "Tracking", "Rules", "Blocking", "Privacy"].map((item) => {
            const selected = item === "Blocking";
            return (
              <div
                key={item}
                style={{
                  position: "relative",
                  height: 44,
                  display: "flex",
                  alignItems: "center",
                  padding: "0 12px",
                  marginBottom: 6,
                  borderRadius: 12,
                  background: selected ? "rgba(232,199,167,0.18)" : "transparent",
                  color: selected ? COLORS.cream : COLORS.creamMuted,
                  fontSize: 12,
                }}
              >
                {selected && <span style={{ position: "absolute", left: 0, width: 3, height: 24, borderRadius: 99, background: COLORS.sand }} />}
                <span style={{ width: 24, color: selected ? COLORS.sand : COLORS.creamMuted }}>{selected ? "◆" : "◇"}</span>
                {item}
              </div>
            );
          })}
        </ContentSurface>
        <ContentSurface style={{ flex: 1, overflow: "hidden" }}>
          <div style={{ padding: 22 }}>
            <div style={{ color: COLORS.cream, fontSize: 18, fontWeight: 650 }}>Blocking</div>
            <div style={{ marginTop: 5, color: COLORS.creamMuted, fontSize: 12 }}>Choose the websites Focus keeps quiet</div>
          </div>
          <div style={{ height: 1, background: COLORS.line }} />
          <div style={{ display: "flex", gap: 10, padding: 18 }}>
            <div
              style={{
                flex: 1,
                height: 42,
                display: "flex",
                alignItems: "center",
                padding: "0 13px",
                borderRadius: 11,
                background: "rgba(17,16,22,0.72)",
                border: "1px solid " + COLORS.line,
                color: COLORS.creamMuted,
                fontSize: 12,
              }}
            >
              example.com
            </div>
            <div
              style={{
                height: 42,
                display: "flex",
                alignItems: "center",
                padding: "0 18px",
                borderRadius: 999,
                background: COLORS.sand,
                color: COLORS.sandInk,
                fontSize: 12,
                fontWeight: 750,
              }}
            >
              ＋ Add website
            </div>
          </div>
          <div style={{ height: 1, background: COLORS.line }} />
          {sites.map((site, index) => {
            const opacity = interpolate(t, [12 + index * 8, 24 + index * 8], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            return (
              <div
                key={site}
                style={{
                  opacity,
                  height: 58,
                  display: "flex",
                  alignItems: "center",
                  padding: "0 20px",
                  borderBottom: "1px solid " + COLORS.line,
                }}
              >
                <div>
                  <div style={{ color: COLORS.cream, fontSize: 12, fontWeight: 600 }}>{site}</div>
                  <div style={{ marginTop: 4, color: COLORS.creamMuted, fontSize: 10 }}>Enabled for Focus</div>
                </div>
                <div style={{ flex: 1 }} />
                <Toggle on />
                <span style={{ marginLeft: 15, color: COLORS.distraction }}>⌫</span>
              </div>
            );
          })}
        </ContentSurface>
      </div>
    </div>
  );
};

const BlockedBrowser: React.FC<{ t: number }> = ({ t }) => {
  const opacity = interpolate(t, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const panelY = interpolate(t, [0, 14], [8, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ ...windowFrameStyle, background: "#070719", opacity }}>
      <div
        style={{
          height: 74,
          background: "#18151C",
          borderBottom: "1px solid rgba(255,255,255,0.10)",
        }}
      >
        <div style={{ height: 34, display: "flex", alignItems: "center", gap: 8, padding: "0 14px" }}>
          <TrafficDot color="#FF5F57" />
          <TrafficDot color="#FEBC2E" />
          <TrafficDot color="#28C840" />
          <div style={{ width: 260, height: 27, marginLeft: 18, padding: "0 13px", display: "flex", alignItems: "center", background: "#2A2525", color: COLORS.cream, fontSize: 11, borderRadius: "8px 8px 0 0" }}>
            Stay focused — Drift
          </div>
        </div>
        <div style={{ height: 40, display: "flex", alignItems: "center", gap: 13, padding: "0 18px" }}>
          <span style={{ color: COLORS.creamMuted }}>‹</span>
          <span style={{ color: COLORS.creamMuted }}>›</span>
          <div
            style={{
              flex: 1,
              height: 28,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              borderRadius: 8,
              background: "#0E0D12",
              color: COLORS.creamMuted,
              fontFamily: FONTS.mono,
              fontSize: 10,
            }}
          >
            data:text/html — Drift Focus protection
          </div>
        </div>
      </div>
      <BlockedPage panelY={panelY} />
    </div>
  );
};

const BlockedPage: React.FC<{ panelY: number }> = ({ panelY }) => (
  <div
    style={{
      position: "absolute",
      top: 74,
      right: 0,
      bottom: 0,
      left: 0,
      overflow: "hidden",
      background: "linear-gradient(180deg,#070719 0%,#17102C 50%,#48213A 76%,#A74831 100%)",
    }}
  >
    <StarField />
    <Mesa />
    <div
      style={{
        position: "absolute",
        top: 28,
        left: 32,
        display: "flex",
        alignItems: "center",
        gap: 11,
        color: COLORS.cream,
        fontFamily: FONTS.mono,
        fontSize: 12,
        fontWeight: 800,
        letterSpacing: 2,
      }}
    >
      <div
        style={{
          width: 31,
          height: 31,
          display: "grid",
          placeItems: "center",
          background: COLORS.sand,
          border: "1px solid rgba(255,243,223,0.58)",
          color: COLORS.cocoa,
          boxShadow: "4px 4px 0 rgba(7,4,13,0.42)",
          fontFamily: FONTS.pixel,
          fontSize: 11,
          letterSpacing: 0,
        }}
      >
        D
      </div>
      DRIFT
    </div>
    <div
      style={{
        position: "absolute",
        top: 30,
        right: 32,
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "8px 12px",
        background: "rgba(17,16,22,0.64)",
        border: "1px solid rgba(82,169,107,0.34)",
        color: COLORS.cream,
        fontSize: 10,
        fontWeight: 750,
        letterSpacing: 1,
      }}
    >
      <span style={{ width: 7, height: 7, background: COLORS.productive }} />
      FOCUS ACTIVE
    </div>
    <div
      style={{
        position: "absolute",
        top: "50%",
        left: "50%",
        width: 570,
        padding: 44,
        borderRadius: 18,
        background: "rgba(36,26,22,0.95)",
        border: "1px solid " + COLORS.line,
        boxShadow: "9px 9px 0 rgba(7,4,13,0.42),0 28px 80px rgba(4,2,10,0.32)",
        transform: "translate(-50%,calc(-50% + " + panelY + "px))",
      }}
    >
      <div style={{ display: "flex", gap: 20, alignItems: "flex-start" }}>
        <div
          style={{
            width: 68,
            height: 68,
            display: "grid",
            placeItems: "center",
            background: "rgba(232,199,167,0.11)",
            border: "1px solid rgba(232,199,167,0.28)",
            boxShadow: "5px 5px 0 rgba(7,4,13,0.36)",
          }}
        >
          <ShieldIcon color={COLORS.sand} />
        </div>
        <div>
          <div style={{ color: COLORS.distraction, fontFamily: FONTS.mono, fontSize: 10, fontWeight: 800, letterSpacing: 1.6 }}>
            DISTRACTION INTERCEPTED
          </div>
          <h2 style={{ margin: "10px 0 0", color: COLORS.cream, fontSize: 33, letterSpacing: -1.2 }}>
            Stay in the zone.
          </h2>
        </div>
      </div>
      <p style={{ margin: "24px 0", color: COLORS.creamMuted, fontSize: 14, lineHeight: 1.6 }}>
        <strong style={{ color: COLORS.cream }}>Drift blocked this page while Focus is active.</strong>
        <br />
        Your session is still moving. Return to the work you chose.
      </p>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 13,
          padding: "14px 16px",
          borderRadius: 12,
          background: "rgba(17,16,22,0.62)",
          border: "1px solid " + COLORS.line,
        }}
      >
        <span
          style={{
            width: 30,
            height: 30,
            display: "grid",
            placeItems: "center",
            background: "rgba(230,108,92,0.10)",
            color: COLORS.distraction,
            fontWeight: 900,
          }}
        >
          ×
        </span>
        <div>
          <SectionLabel>Blocked website</SectionLabel>
          <div style={{ marginTop: 4, color: COLORS.cream, fontFamily: FONTS.mono, fontSize: 13, fontWeight: 700 }}>
            reddit.com
          </div>
        </div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8, margin: "15px 0 26px", color: COLORS.creamMuted, fontSize: 11 }}>
        <span style={{ width: 6, height: 6, background: COLORS.productive }} />
        Focus protection is running on this Mac
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
        <div
          style={{
            minHeight: 44,
            display: "flex",
            alignItems: "center",
            padding: "0 22px",
            borderRadius: 999,
            background: COLORS.sand,
            color: COLORS.sandInk,
            fontSize: 13,
            fontWeight: 750,
          }}
        >
          Return to focus&nbsp; →
        </div>
        <div style={{ color: COLORS.creamMuted, fontSize: 10, lineHeight: 1.4 }}>
          Private by design.
          <br />
          Nothing was uploaded.
        </div>
      </div>
    </div>
  </div>
);

const StarField: React.FC = () => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      opacity: 0.72,
      backgroundImage:
        "radial-gradient(circle at 7% 16%,#FFE38F 0 1px,transparent 2px)," +
        "radial-gradient(circle at 18% 31%,#FFF3DF 0 1px,transparent 2px)," +
        "radial-gradient(circle at 31% 11%,#FFE38F 0 2px,transparent 3px)," +
        "radial-gradient(circle at 46% 25%,#FFF3DF 0 1px,transparent 2px)," +
        "radial-gradient(circle at 61% 13%,#FFE38F 0 1px,transparent 2px)," +
        "radial-gradient(circle at 72% 34%,#FFF3DF 0 2px,transparent 3px)," +
        "radial-gradient(circle at 86% 18%,#FFE38F 0 1px,transparent 2px)," +
        "radial-gradient(circle at 94% 41%,#FFF3DF 0 1px,transparent 2px)",
    }}
  />
);

const Mesa: React.FC = () => (
  <>
    <div
      style={{
        position: "absolute",
        right: "-5%",
        bottom: "-5%",
        left: "-5%",
        height: "31%",
        background: "#54243A",
        clipPath:
          "polygon(0 65%,10% 38%,18% 58%,29% 29%,42% 66%,55% 44%,70% 62%,82% 26%,92% 52%,100% 34%,100% 100%,0 100%)",
      }}
    />
    <div
      style={{
        position: "absolute",
        right: "-5%",
        bottom: "-5%",
        left: "-5%",
        height: "22%",
        background: "#8E382F",
        clipPath:
          "polygon(0 57%,14% 34%,25% 62%,39% 42%,55% 70%,69% 36%,84% 61%,100% 28%,100% 100%,0 100%)",
      }}
    />
  </>
);

const ShieldIcon: React.FC<{ color: string }> = ({ color }) => (
  <svg width="34" height="34" viewBox="0 0 24 24" fill={color}>
    <path d="M12 2 4 5.5v5.3c0 5.1 3.4 9.8 8 11.2 4.6-1.4 8-6.1 8-11.2V5.5L12 2Zm-1.1 14.3-3.5-3.5 1.3-1.3 2.2 2.2 4.7-4.7 1.3 1.3-6 6Z" />
  </svg>
);

const TourCursor: React.FC<{ phase: TabKey; t: number }> = ({ phase, t }) => {
  const navIndex = TABS.findIndex((tab) => tab.key === phase);
  const navY = TITLEBAR_HEIGHT + 108 + 8 + navIndex * 54 + 23;
  let x = 105;
  let y = navY;
  let clickAt = 12;

  if (phase === "focus" && t > 38) {
    x = interpolate(t, [38, 68], [105, 990], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    y = interpolate(t, [38, 68], [navY, 735], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    clickAt = 72;
  }
  if (phase === "settings" && t > 34) {
    x = interpolate(t, [34, 62], [105, 370], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    y = interpolate(t, [34, 62], [navY, 474], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    clickAt = 66;
  }

  const distance = t - clickAt;
  const pulse =
    distance >= 0 && distance < 12
      ? Math.sin((distance / 12) * Math.PI)
      : 0;

  return <Cursor x={x} y={y} pulse={pulse} />;
};

const Cursor: React.FC<{ x: number; y: number; pulse: number }> = ({
  x,
  y,
  pulse,
}) => (
  <div
    style={{
      position: "absolute",
      top: y,
      left: x,
      zIndex: 30,
      transform: "translate(-3px,-2px)",
    }}
  >
    {pulse > 0 && (
      <div
        style={{
          position: "absolute",
          top: -18,
          left: -18,
          width: 40,
          height: 40,
          borderRadius: "50%",
          border: "2px solid " + COLORS.sand,
          opacity: 1 - pulse,
          transform: "scale(" + (0.4 + pulse * 1.1) + ")",
        }}
      />
    )}
    <svg
      width="26"
      height="32"
      viewBox="0 0 26 32"
      style={{ filter: "drop-shadow(0 3px 6px rgba(0,0,0,0.5))" }}
    >
      <path
        d="M2 2 2 24 8 18 12 27 16 25 12 16 20 16Z"
        fill={COLORS.cream}
        stroke="rgba(0,0,0,0.62)"
        strokeWidth="1.2"
      />
    </svg>
  </div>
);

const PanelHeader: React.FC<{ title: string }> = ({ title }) => (
  <div style={{ height: 48, display: "flex", alignItems: "center", padding: "0 18px" }}>
    <SectionLabel>{title}</SectionLabel>
  </div>
);

const StatusTag: React.FC<{ text: string; color: string }> = ({ text, color }) => (
  <span
    style={{
      padding: "5px 10px",
      borderRadius: 999,
      color,
      background: color + "18",
      border: "1px solid " + color + "38",
      fontSize: 10,
      fontWeight: 700,
    }}
  >
    {text}
  </span>
);

const Pill: React.FC<{ text: string; accent?: boolean }> = ({ text, accent = false }) => (
  <span
    style={{
      minHeight: 34,
      display: "inline-flex",
      alignItems: "center",
      padding: "0 14px",
      borderRadius: 999,
      color: accent ? COLORS.sandInk : COLORS.cream,
      background: accent ? COLORS.sand : "rgba(17,16,22,0.66)",
      border: "1px solid " + (accent ? COLORS.sand : COLORS.line),
      fontSize: 11,
      fontWeight: 650,
    }}
  >
    {text}
  </span>
);

const Toggle: React.FC<{ on: boolean }> = ({ on }) => (
  <div
    style={{
      position: "relative",
      width: 38,
      height: 22,
      borderRadius: 999,
      background: on ? COLORS.sand : "rgba(255,243,223,0.14)",
    }}
  >
    <span
      style={{
        position: "absolute",
        top: 2,
        left: on ? 18 : 2,
        width: 18,
        height: 18,
        borderRadius: "50%",
        background: on ? COLORS.cocoa : COLORS.cream,
      }}
    />
  </div>
);

const Segmented: React.FC<{ options: string[]; selected: number }> = ({
  options,
  selected,
}) => (
  <div
    style={{
      display: "flex",
      gap: 4,
      padding: 4,
      borderRadius: 12,
      background: "rgba(17,16,22,0.65)",
      border: "1px solid " + COLORS.line,
    }}
  >
    {options.map((option, index) => (
      <span
        key={option}
        style={{
          minWidth: 74,
          height: 32,
          display: "grid",
          placeItems: "center",
          borderRadius: 9,
          color: index === selected ? COLORS.cocoa : COLORS.creamMuted,
          background: index === selected ? COLORS.sand : "transparent",
          fontSize: 11,
          fontWeight: 650,
        }}
      >
        {option}
      </span>
    ))}
  </div>
);

const screenTitleStyle: React.CSSProperties = {
  margin: 0,
  color: COLORS.cream,
  fontFamily: FONTS.pixel,
  fontSize: 24,
  fontWeight: 400,
};

const screenSubtitleStyle: React.CSSProperties = {
  margin: "12px 0 0",
  color: COLORS.creamMuted,
  fontSize: 14,
};

const CTAScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const scale = spring({ frame, fps, config: { damping: 15, mass: 0.75 } });
  const opacity = interpolate(frame, [8, 28], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const buttonOpacity = interpolate(frame, [28, 48], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill>
      <PixelBackdrop name="settings" wash={0.52} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "column",
          textAlign: "center",
        }}
      >
        <Img
          src={staticFile("drift-current/logo.png")}
          style={{
            width: 94,
            height: 94,
            imageRendering: "pixelated",
            transform: "scale(" + scale + ")",
          }}
        />
        <h2
          style={{
            margin: "32px 0 0",
            color: COLORS.cream,
            fontFamily: FONTS.pixel,
            fontSize: 35,
            fontWeight: 400,
            opacity,
            textShadow: "0 5px 0 rgba(36,26,22,0.86)",
          }}
        >
          FOCUS WITHOUT SURVEILLANCE.
        </h2>
        <p style={{ margin: "20px 0 0", color: COLORS.creamMuted, fontSize: 19, opacity }}>
          Private. Local. Yours.
        </p>
        <div
          style={{
            marginTop: 34,
            minHeight: 50,
            display: "flex",
            alignItems: "center",
            padding: "0 30px",
            borderRadius: 999,
            color: COLORS.cream,
            background:
              "linear-gradient(145deg,rgba(255,255,255,0.30),rgba(255,225,187,0.16)),rgba(226,174,133,0.52)",
            border: "1px solid rgba(255,255,255,0.54)",
            boxShadow: "0 18px 48px rgba(4,1,18,0.34)",
            fontSize: 15,
            fontWeight: 750,
            opacity: buttonOpacity,
          }}
        >
          Try Drift locally&nbsp; →
        </div>
        <div style={{ marginTop: 18, color: COLORS.creamMuted, fontSize: 12, opacity: buttonOpacity }}>
          macOS 14+ · Apple silicon · No account required
        </div>
      </div>
    </AbsoluteFill>
  );
};
