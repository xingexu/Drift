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

// Shorter landing page version (15 seconds at 30fps = 450 frames)
export const DriftLandingDemo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg }}>
      {/* Scene 1: Hero (0-120 / 0-4s) */}
      <Sequence from={0} durationInFrames={120}>
        <HeroScene />
      </Sequence>

      {/* Scene 2: Features Carousel (120-300 / 4-10s) */}
      <Sequence from={120} durationInFrames={180}>
        <FeaturesCarousel />
      </Sequence>

      {/* Scene 3: Download CTA (300-450 / 10-15s) */}
      <Sequence from={300} durationInFrames={150}>
        <DownloadCTA />
      </Sequence>
    </AbsoluteFill>
  );
};

const HeroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame, fps, config: { damping: 10, mass: 0.5 } });
  const textFade = interpolate(frame, [15, 35], [0, 1], { extrapolateRight: "clamp" });
  const textY = interpolate(frame, [15, 40], [40, 0], { extrapolateRight: "clamp" });

  // Animated gradient
  const gradX = 30 + Math.sin(frame * 0.02) * 10;
  const gradY = 40 + Math.cos(frame * 0.015) * 10;

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        background: `radial-gradient(circle at ${gradX}% ${gradY}%, ${COLORS.drift}18, transparent 60%), ${COLORS.bg}`,
      }}
    >
      <div style={{ textAlign: "center" }}>
        {/* Logo */}
        <div
          style={{
            width: 80,
            height: 80,
            borderRadius: 20,
            background: `linear-gradient(135deg, ${COLORS.drift}, ${COLORS.driftDark})`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            margin: "0 auto 24px",
            transform: `scale(${logoScale})`,
            boxShadow: `0 16px 48px ${COLORS.drift}35`,
          }}
        >
          <span style={{ fontSize: 42, fontWeight: 800, color: "white", fontFamily: FONTS.display }}>D</span>
        </div>

        {/* Text */}
        <div style={{ opacity: textFade, transform: `translateY(${textY}px)` }}>
          <h1
            style={{
              fontSize: 48,
              fontWeight: 800,
              color: COLORS.text,
              fontFamily: FONTS.display,
              margin: 0,
              letterSpacing: -1.5,
              lineHeight: 1.1,
            }}
          >
            Know where your<br />time goes.
          </h1>
          <p
            style={{
              fontSize: 18,
              color: COLORS.textSecondary,
              fontFamily: FONTS.display,
              marginTop: 14,
            }}
          >
            AI-powered focus tracking for macOS
          </p>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const FeaturesCarousel: React.FC = () => {
  const frame = useCurrentFrame();

  const features = [
    {
      icon: "&#x1F441;",
      title: "Smart Tracking",
      desc: "Automatically detects and classifies every app you use",
      color: COLORS.drift,
    },
    {
      icon: "&#x1F3AF;",
      title: "Focus Score",
      desc: "Real-time productivity percentage that updates live",
      color: COLORS.green,
    },
    {
      icon: "&#x23F2;",
      title: "Pomodoro Timer",
      desc: "Built-in focus timer with customizable intervals",
      color: COLORS.orange,
    },
    {
      icon: "&#x1F6E1;",
      title: "Site Blocker",
      desc: "Block distracting websites with password lock",
      color: COLORS.purple,
    },
  ];

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        background: COLORS.bg,
        padding: 60,
      }}
    >
      <div style={{ width: "100%" }}>
        <p
          style={{
            fontSize: 13,
            fontWeight: 700,
            color: COLORS.drift,
            fontFamily: FONTS.display,
            textTransform: "uppercase",
            letterSpacing: 3,
            textAlign: "center",
            margin: 0,
            marginBottom: 12,
            opacity: interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" }),
          }}
        >
          Features
        </p>
        <h2
          style={{
            fontSize: 40,
            fontWeight: 800,
            color: COLORS.text,
            fontFamily: FONTS.display,
            textAlign: "center",
            margin: 0,
            marginBottom: 48,
            letterSpacing: -1,
            opacity: interpolate(frame, [5, 25], [0, 1], { extrapolateRight: "clamp" }),
          }}
        >
          Everything you need to stay focused
        </h2>

        <div style={{ display: "flex", gap: 20, justifyContent: "center" }}>
          {features.map((feature, i) => {
            const delay = 15 + i * 15;
            const opacity = interpolate(frame, [delay, delay + 20], [0, 1], { extrapolateRight: "clamp" });
            const translateY = interpolate(frame, [delay, delay + 20], [30, 0], { extrapolateRight: "clamp" });

            return (
              <div
                key={i}
                style={{
                  flex: 1,
                  background: COLORS.surface,
                  borderRadius: 16,
                  padding: 28,
                  border: `1px solid rgba(255,255,255,0.05)`,
                  opacity,
                  transform: `translateY(${translateY}px)`,
                  textAlign: "center",
                }}
              >
                <div
                  style={{
                    width: 48,
                    height: 48,
                    borderRadius: 14,
                    background: `${feature.color}15`,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    margin: "0 auto 16px",
                    fontSize: 24,
                  }}
                  dangerouslySetInnerHTML={{ __html: feature.icon }}
                />
                <h3
                  style={{
                    fontSize: 17,
                    fontWeight: 700,
                    color: COLORS.text,
                    fontFamily: FONTS.display,
                    margin: "0 0 8px",
                  }}
                >
                  {feature.title}
                </h3>
                <p
                  style={{
                    fontSize: 13,
                    color: COLORS.textSecondary,
                    fontFamily: FONTS.display,
                    lineHeight: 1.5,
                    margin: 0,
                  }}
                >
                  {feature.desc}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const DownloadCTA: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({ frame, fps, config: { damping: 14, mass: 0.5 } });
  const textFade = interpolate(frame, [10, 30], [0, 1], { extrapolateRight: "clamp" });
  const buttonFade = interpolate(frame, [30, 50], [0, 1], { extrapolateRight: "clamp" });
  const buttonY = interpolate(frame, [30, 50], [20, 0], { extrapolateRight: "clamp" });

  // Pulse effect on button
  const pulse = Math.sin(frame * 0.08) * 0.03 + 1;

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        background: `
          radial-gradient(circle at 40% 30%, ${COLORS.drift}10, transparent 50%),
          radial-gradient(circle at 60% 70%, ${COLORS.green}08, transparent 40%),
          ${COLORS.bg}
        `,
      }}
    >
      <div style={{ textAlign: "center", transform: `scale(${scale})` }}>
        {/* Logo */}
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: 18,
            background: `linear-gradient(135deg, ${COLORS.drift}, ${COLORS.driftDark})`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            margin: "0 auto 28px",
            boxShadow: `0 16px 40px ${COLORS.drift}30`,
          }}
        >
          <span style={{ fontSize: 38, fontWeight: 800, color: "white", fontFamily: FONTS.display }}>D</span>
        </div>

        <h1
          style={{
            fontSize: 44,
            fontWeight: 800,
            color: COLORS.text,
            fontFamily: FONTS.display,
            margin: 0,
            letterSpacing: -1.5,
            opacity: textFade,
          }}
        >
          Ready to focus?
        </h1>

        <p
          style={{
            fontSize: 18,
            color: COLORS.textSecondary,
            fontFamily: FONTS.display,
            marginTop: 12,
            opacity: textFade,
          }}
        >
          Download Drift for free. Native macOS app.
        </p>

        <div
          style={{
            marginTop: 36,
            opacity: buttonFade,
            transform: `translateY(${buttonY}px) scale(${pulse})`,
          }}
        >
          <div
            style={{
              display: "inline-block",
              padding: "14px 40px",
              borderRadius: 12,
              background: `linear-gradient(135deg, ${COLORS.drift}, ${COLORS.driftDark})`,
              fontSize: 16,
              fontWeight: 700,
              color: "white",
              fontFamily: FONTS.display,
              boxShadow: `0 10px 30px ${COLORS.drift}35`,
            }}
          >
            Download for macOS
          </div>
        </div>

        <p
          style={{
            fontSize: 12,
            color: COLORS.textTertiary,
            fontFamily: FONTS.display,
            marginTop: 16,
            opacity: buttonFade,
          }}
        >
          macOS 14+ &bull; Apple Silicon &bull; Free forever
        </p>
      </div>
    </AbsoluteFill>
  );
};
