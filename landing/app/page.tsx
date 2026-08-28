"use client";

import { useEffect, useRef } from "react";

const SCENE_WIDTH = 3072;
const SCENE_HEIGHT = 2048;
const SOURCE_IMAGE = "/art/drift-original-scene-2x.png";
const SCENE_DROP = 118;
const GITHUB_REPOSITORY_URL = "https://github.com/xingexu/Drift";
const EMAIL_COMPOSE_URL =
  "https://mail.google.com/mail/?view=cm&fs=1&to=xingexu1107%40gmail.com";

type PixelContext = CanvasRenderingContext2D;

const starbursts = [
  { x: 132, y: 592, delay: 0.1 },
  { x: 1132, y: 100, delay: 1.2 },
  { x: 2146, y: 224, delay: 0.7 },
  { x: 2540, y: 1158, delay: 1.8 },
  { x: 2918, y: 700, delay: 2.4 },
  { x: 1760, y: 304, delay: 1.5 },
  { x: 2428, y: 546, delay: 0.4 },
];

const meteors = [
  { startX: -760, startY: -430, delay: 0, duration: 27 },
  { startX: -700, startY: -250, delay: 9, duration: 27 },
  { startX: -640, startY: -560, delay: 18, duration: 27 },
];

const ruffles = [
  { x: 395, y: 1830, delay: 0.2 },
  { x: 1080, y: 1888, delay: 1.4 },
  { x: 1610, y: 1798, delay: 2.8 },
  { x: 2260, y: 1846, delay: 3.6 },
  { x: 2760, y: 1900, delay: 0.9 },
];

const pixelMarks = {
  mail: [
    "000000000000000",
    "001111111111100",
    "001000000000100",
    "001100000001100",
    "001110000011100",
    "001011000110100",
    "001001101100100",
    "001000111000100",
    "001000010000100",
    "001000000000100",
    "001000000000100",
    "001111111111100",
    "000000000000000",
    "000000000000000",
    "000000000000000",
  ],
} as const;

type PixelMark = keyof typeof pixelMarks;
type BrandMark = "github" | "linkedin";

const pixelStars = Array.from({ length: 170 }, (_, index) => {
  const seed = (index + 3) * 9301 + 49297;
  const x = (seed * 37 + index * 97) % SCENE_WIDTH;
  const y = -260 + ((seed * 53 + index * 41) % 1380);
  const size = index % 22 === 0 ? 5 : 3;
  const delay = (index % 29) * 0.27;
  const color = index % 5 === 0 ? "#ffd28a" : index % 3 === 0 ? "#a87ea1" : "#ffe99a";
  return { x, y, size, delay, color };
});

function pixel(ctx: PixelContext, x: number, y: number, width: number, height: number, color: string) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.round(x), Math.round(y), Math.round(width), Math.round(height));
}

function drawSkyExtension(ctx: PixelContext) {
  pixel(ctx, 0, -620, SCENE_WIDTH, 180, "#090416");
  pixel(ctx, 0, -440, SCENE_WIDTH, 160, "#0b051a");
  pixel(ctx, 0, -280, SCENE_WIDTH, 140, "#0d061f");
  pixel(ctx, 0, -140, SCENE_WIDTH, 130, "#100824");
  pixel(ctx, 0, -10, SCENE_WIDTH, 150, "#120927");
  pixel(ctx, 0, 112, SCENE_WIDTH, 36, "#120927");
}

function drawTinyStar(ctx: PixelContext, x: number, y: number, size: number, color: string, alpha: number) {
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
  pixel(ctx, x, y, size, size, color);
  if (alpha > 0.72) {
    pixel(ctx, x - size, y, size, size, color);
    pixel(ctx, x + size, y, size, size, color);
    pixel(ctx, x, y - size, size, size, color);
    pixel(ctx, x, y + size, size, size, color);
  }
  ctx.globalAlpha = 1;
}

function drawTinyStars(ctx: PixelContext, elapsed: number) {
  for (const star of pixelStars) {
    const pulse = (Math.sin((elapsed + star.delay) * 1.4) + 1) / 2;
    drawTinyStar(ctx, star.x, star.y, star.size, star.color, 0.36 + pulse * 0.58);
  }
}

function drawStarburst(ctx: PixelContext, x: number, y: number, size: number, alpha: number) {
  ctx.globalAlpha = alpha * 0.16;
  pixel(ctx, x - size * 2, y - size * 2, size * 5, size * 5, "#fff1a7");
  ctx.globalAlpha = alpha;
  pixel(ctx, x, y, size, size, "#fff1a7");
  pixel(ctx, x - size, y, size, size, "#ffd05e");
  pixel(ctx, x + size, y, size, size, "#ffd05e");
  pixel(ctx, x, y - size, size, size, "#ffd05e");
  pixel(ctx, x, y + size, size, size, "#d9984d");
  ctx.globalAlpha = 1;
}

function drawMeteor(ctx: PixelContext, elapsed: number, meteor: (typeof meteors)[number]) {
  const cycle = ((elapsed - meteor.delay) % meteor.duration + meteor.duration) % meteor.duration;
  if (cycle > 7.4) {
    return;
  }

  const progress = cycle / 7.4;
  const headX = meteor.startX + progress * 4320;
  const headY = meteor.startY + progress * 2140;
  const colors = ["#fff1a7", "#ffe07a", "#ffc35d", "#d18463", "#8d5b7f", "#4a315f"];

  for (let i = 0; i < 15; i += 1) {
    const alpha = Math.max(0, 1 - i * 0.07 - progress * 0.1);
    const tailX = headX - i * 19;
    const tailY = headY - i * 10;
    ctx.globalAlpha = alpha;
    pixel(ctx, tailX, tailY, 8, 8, colors[Math.min(Math.floor(i / 8), colors.length - 1)]);
  }

  ctx.globalAlpha = 1;
}

function drawFluffyCloud(ctx: PixelContext, x: number, y: number, scale = 1) {
  const unit = 12 * scale;
  ctx.globalAlpha = 0.72;
  pixel(ctx, x, y + unit * 4, unit * 17, unit * 2, "#4b2d67");
  pixel(ctx, x + unit, y + unit * 3, unit * 4, unit * 2, "#563573");
  pixel(ctx, x + unit * 3, y + unit * 2, unit * 5, unit * 3, "#61407d");
  pixel(ctx, x + unit * 6, y + unit, unit * 5, unit * 3, "#76518c");
  pixel(ctx, x + unit * 10, y + unit * 2, unit * 5, unit * 3, "#5b3978");
  pixel(ctx, x + unit * 14, y + unit * 3, unit * 4, unit * 2, "#4b2d67");
  pixel(ctx, x + unit * 3, y + unit * 4, unit * 3, unit, "#856197");
  pixel(ctx, x + unit * 8, y + unit * 3, unit * 3, unit, "#8c6a9d");
  pixel(ctx, x + unit * 13, y + unit * 4, unit * 2, unit, "#75518d");
  pixel(ctx, x + unit * 16, y + unit * 5, unit * 2, unit, "#2f1d4b");
  ctx.globalAlpha = 1;
}

function drawFluffyClouds(ctx: PixelContext) {
  drawFluffyCloud(ctx, 92, 500, 1.32);
  drawFluffyCloud(ctx, 410, 340, 1.08);
  drawFluffyCloud(ctx, 1100, 395, 1.18);
  drawFluffyCloud(ctx, 1720, 360, 1.08);
  drawFluffyCloud(ctx, 2240, 392, 1.02);
  drawFluffyCloud(ctx, 2680, 535, 1.16);
}

function patchOriginalTitle(ctx: PixelContext, image: HTMLImageElement) {
  ctx.drawImage(image, 986, 330, 1080, 350, 986, 590, 1080, 350);
  ctx.globalAlpha = 0.36;
  pixel(ctx, 1012, 640, 160, 28, "#110824");
  pixel(ctx, 1286, 668, 170, 24, "#160b2f");
  pixel(ctx, 1528, 664, 190, 26, "#0f0822");
  pixel(ctx, 1772, 654, 170, 24, "#150b2f");
  pixel(ctx, 1150, 792, 210, 30, "#160b2f");
  pixel(ctx, 1464, 806, 260, 28, "#110824");
  pixel(ctx, 1818, 780, 190, 30, "#160b2f");
  ctx.globalAlpha = 1;
}

function patchOriginalButtons(ctx: PixelContext, image: HTMLImageElement) {
  ctx.drawImage(image, 80, 980, 700, 200, 840, 980, 700, 200);
  ctx.drawImage(image, 2290, 980, 700, 200, 1530, 980, 700, 200);
}

function patchOriginalMoon(ctx: PixelContext, image: HTMLImageElement) {
  ctx.drawImage(image, 2040, 240, 620, 500, 2520, 170, 620, 500);
  ctx.globalAlpha = 0.34;
  pixel(ctx, 2540, 300, 160, 36, "#0d061f");
  pixel(ctx, 2790, 380, 180, 44, "#100824");
  pixel(ctx, 2620, 520, 240, 40, "#120927");
  ctx.globalAlpha = 1;
}

function drawSmallMoon(ctx: PixelContext) {
  const x = 2722;
  const y = 236;
  const cells = [
    [4, 0, 5, 1, "#ffea92"],
    [2, 1, 9, 1, "#ffea92"],
    [1, 2, 11, 1, "#ffea92"],
    [0, 3, 13, 7, "#ffea92"],
    [1, 10, 11, 1, "#ffea92"],
    [2, 11, 9, 1, "#ffea92"],
    [4, 12, 5, 1, "#ffea92"],
    [11, 2, 1, 1, "#f1c55e"],
    [12, 3, 1, 7, "#cb843e"],
    [11, 4, 1, 5, "#dfa34a"],
    [10, 9, 2, 1, "#edb854"],
    [9, 10, 2, 1, "#e3a74b"],
    [8, 11, 3, 1, "#d99443"],
    [4, 12, 5, 1, "#c9823b"],
    [4, 3, 2, 2, "#d99c4a"],
    [7, 7, 2, 2, "#d99c4a"],
    [9, 4, 1, 2, "#f6d875"],
    [3, 8, 1, 1, "#e0a44a"],
    [5, 3, 1, 1, "#efbd59"],
  ];

  for (const [cellX, cellY, cellW, cellH, color] of cells) {
    pixel(ctx, x + Number(cellX) * 12, y + Number(cellY) * 12, Number(cellW) * 12, Number(cellH) * 12, String(color));
  }
}

function drawCactusSpikes(ctx: PixelContext) {
  const spikeColor = "#d5e65c";
  const shadowColor = "#102d22";
  const spikes = [
    [256, 1470], [282, 1584], [306, 1692], [344, 1448], [376, 1618],
    [2600, 1484], [2634, 1606], [2674, 1718], [2748, 1486], [2798, 1638],
    [682, 1660], [1318, 1728], [2164, 1650],
  ];

  for (const [x, y] of spikes) {
    pixel(ctx, x - 16, y, 12, 4, spikeColor);
    pixel(ctx, x + 6, y + 16, 12, 4, shadowColor);
    pixel(ctx, x - 10, y + 38, 10, 4, spikeColor);
  }
}

function drawSandRuffle(ctx: PixelContext, x: number, y: number, offset: number) {
  const dx = Math.round(offset) * 4;
  pixel(ctx, x + dx, y, 78, 8, "rgba(96, 40, 39, .62)");
  pixel(ctx, x + 24 + dx, y + 8, 92, 8, "rgba(180, 72, 41, .56)");
  pixel(ctx, x + 62 + dx, y + 16, 74, 8, "rgba(238, 119, 41, .54)");
  pixel(ctx, x - 34 + dx, y + 16, 42, 8, "rgba(119, 47, 43, .44)");
}

function drawLizardBody(ctx: PixelContext) {
  pixel(ctx, 56, 52, 150, 12, "rgba(37, 20, 28, .45)");
  pixel(ctx, 14, 42, 58, 14, "#143426");
  pixel(ctx, -8, 30, 28, 12, "#143426");
  pixel(ctx, -20, 14, 26, 12, "#4f8437");
  pixel(ctx, -8, 0, 32, 12, "#143426");
  pixel(ctx, 22, 0, 18, 12, "#4f8437");
  pixel(ctx, 38, 14, 18, 12, "#143426");
  pixel(ctx, 28, 28, 28, 12, "#4f8437");
  pixel(ctx, 68, 28, 98, 34, "#244c31");
  pixel(ctx, 68, 28, 22, 34, "#8dac41");
  pixel(ctx, 144, 28, 22, 34, "#102d22");
  pixel(ctx, 82, 14, 58, 14, "#6e9638");
  pixel(ctx, 104, 2, 40, 12, "#9fb944");
  pixel(ctx, 156, 24, 48, 36, "#244c31");
  pixel(ctx, 156, 24, 16, 36, "#9fb944");
  pixel(ctx, 190, 36, 24, 16, "#143426");
  pixel(ctx, 182, 28, 10, 10, "#fff4cc");
  pixel(ctx, 190, 28, 6, 10, "#0b1118");
  pixel(ctx, 206, 42, 28, 6, "#e04639");
  pixel(ctx, 232, 36, 18, 6, "#e04639");
  pixel(ctx, 86, 62, 24, 12, "#102d22");
  pixel(ctx, 114, 74, 24, 10, "#102d22");
  pixel(ctx, 150, 62, 24, 12, "#102d22");
  pixel(ctx, 176, 74, 24, 10, "#102d22");
  pixel(ctx, 106, 38, 10, 10, "#b8c957");
  pixel(ctx, 136, 46, 8, 8, "#466d2f");
}

function drawImpactPixels(ctx: PixelContext, x: number, y: number, facing: 1 | -1, phase: number) {
  const active = phase > 0.08 && phase < 0.72;
  if (!active) {
    return;
  }

  const direction = facing;
  const pop = Math.floor(phase * 5) * 5;
  pixel(ctx, x + direction * (246 + pop), y + 24 - pop, 10, 10, "#fff1a7");
  pixel(ctx, x + direction * (266 + pop), y + 40, 8, 8, "#ffd05e");
  pixel(ctx, x + direction * (230 + pop), y + 8, 6, 6, "#d9984d");
}

function drawLizard(ctx: PixelContext, elapsed: number, narrowScene: boolean) {
  const left = narrowScene ? 1480 : 842;
  const right = narrowScene ? 1850 : 1218;
  const walk = 29;
  const bump = 2.8;
  const cycle = walk * 2 + bump * 2;
  const phase = elapsed % cycle;
  let x = left;
  let facing: 1 | -1 = 1;
  let bumpPhase = -1;
  let travelPhase = 0;

  if (phase < walk) {
    travelPhase = phase / walk;
    x = left + (right - left) * travelPhase;
  } else if (phase < walk + bump) {
    bumpPhase = (phase - walk) / bump;
    x = right - Math.floor(Math.sin(bumpPhase * Math.PI) * 34);
    travelPhase = 1;
  } else if (phase < walk * 2 + bump) {
    const walkBack = (phase - walk - bump) / walk;
    travelPhase = 1 - walkBack;
    x = right - (right - left) * walkBack;
    facing = -1;
  } else {
    bumpPhase = (phase - walk * 2 - bump) / bump;
    x = left + Math.floor(Math.sin(bumpPhase * Math.PI) * 34);
    facing = -1;
    travelPhase = 0;
  }

  const stepBob = Math.floor(elapsed * 1.8) % 2 === 0 ? 0 : -4;
  const bumpHop = bumpPhase >= 0 ? -Math.floor(Math.sin(bumpPhase * Math.PI) * 18) : 0;
  const flippedOver = false;
  const y = 1654 + stepBob + bumpHop;
  const width = 250;
  const height = 88;
  const scale = 0.62;

  pixel(ctx, x + 34, y + 55, 100, 5, "rgba(37, 20, 28, .24)");
  drawImpactPixels(ctx, facing === 1 ? x : x + width, y, facing, bumpPhase);

  ctx.save();
  ctx.translate(x + (facing === -1 ? width * scale : 0), y + (flippedOver ? height * scale : 0));
  ctx.scale(facing * scale, (flippedOver ? -1 : 1) * scale);
  drawLizardBody(ctx);
  ctx.restore();
}

function drawSceneEffects(ctx: PixelContext, elapsed: number, narrowScene: boolean) {
  drawTinyStars(ctx, elapsed);

  for (const burst of starbursts) {
    const pulse = (Math.sin((elapsed + burst.delay) * 2.4) + 1) / 2;
    drawStarburst(ctx, burst.x, burst.y, pulse > 0.62 ? 12 : 8, 0.42 + pulse * 0.48);
  }

  for (const activeMeteor of meteors) {
    drawMeteor(ctx, elapsed, activeMeteor);
  }

  drawFluffyClouds(ctx);
  drawCactusSpikes(ctx);

  for (const ruffle of ruffles) {
    const phase = Math.floor((elapsed + ruffle.delay) * 3) % 6;
    drawSandRuffle(ctx, ruffle.x, ruffle.y, phase);
  }

  drawLizard(ctx, elapsed, narrowScene);
}

function PixelLogo({ mark }: { mark: PixelMark }) {
  return (
    <span className={`pixel-logo pixel-logo--${mark}`} aria-hidden="true">
      {pixelMarks[mark].flatMap((row, rowIndex) =>
        Array.from(row).map((cell, columnIndex) => (
          <span
            key={`${rowIndex}-${columnIndex}`}
            className={cell === "1" ? "pixel-logo__dot is-on" : "pixel-logo__dot"}
          />
        )),
      )}
    </span>
  );
}

function BrandLogo({ mark }: { mark: BrandMark }) {
  if (mark === "github") {
    return (
      <svg
        aria-hidden="true"
        className="brand-logo brand-logo--github"
        focusable="false"
        viewBox="0 0 16 16"
      >
        <path
          fill="currentColor"
          d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.65 7.65 0 0 1 3.98 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8Z"
        />
      </svg>
    );
  }

  return (
    <svg
      aria-hidden="true"
      className="brand-logo brand-logo--linkedin"
      focusable="false"
      viewBox="0 0 256 256"
    >
      <path
        fill="currentColor"
        d="M218.123 218.127h-37.931v-59.403c0-14.165-.253-32.4-19.728-32.4-19.756 0-22.779 15.434-22.779 31.369v60.43h-37.93V95.967h36.413v16.694h.51a39.907 39.907 0 0 1 35.928-19.733c38.445 0 45.533 25.288 45.533 58.186l-.016 67.013ZM56.955 79.27c-12.157.002-22.014-9.852-22.016-22.009-.002-12.157 9.851-22.014 22.008-22.016 12.157-.003 22.014 9.851 22.016 22.008A22.013 22.013 0 0 1 56.955 79.27m18.966 138.858H37.95V95.967h37.97v122.16ZM237.033.018H18.89C8.58-.098.125 8.161-.001 18.471v219.053c.122 10.315 8.576 18.582 18.89 18.474h218.144c10.336.128 18.823-8.139 18.966-18.474V18.454c-.147-10.33-8.635-18.588-18.966-18.453"
      />
    </svg>
  );
}

function TryItLink() {
  return (
    <div className="install-picker">
      <span className="install-picker__load-sparkles" aria-hidden="true">
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
      </span>
      <a
        className="install-picker__trigger"
        href={GITHUB_REPOSITORY_URL}
        rel="noreferrer"
        target="_blank"
      >
        <span>Try it</span>
      </a>
    </div>
  );
}

export default function Home() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return;
    }

    const ctx = canvas.getContext("2d");
    if (!ctx) {
      return;
    }

    const image = new Image();
    let frame = 0;
    let loaded = false;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const setSceneHeight = () => {
      const height = Math.max(window.innerHeight, window.visualViewport?.height ?? 0);
      document.documentElement.style.setProperty("--scene-height", `${height}px`);
    };

    const render = (time = 0) => {
      const rect = canvas.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const canvasWidth = Math.max(1, Math.round(rect.width * dpr));
      const canvasHeight = Math.max(1, Math.round(rect.height * dpr));

      if (canvas.width !== canvasWidth || canvas.height !== canvasHeight) {
        canvas.width = canvasWidth;
        canvas.height = canvasHeight;
      }

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, rect.width, rect.height);

      const scale = Math.max(rect.width / SCENE_WIDTH, rect.height / SCENE_HEIGHT);
      const drawWidth = SCENE_WIDTH * scale;
      const drawHeight = SCENE_HEIGHT * scale;
      const offsetX = (rect.width - drawWidth) / 2;
      const offsetY = (rect.height - drawHeight) / 2;

      ctx.save();
      ctx.translate(offsetX, offsetY);
      ctx.scale(scale, scale);
      drawSkyExtension(ctx);
      drawTinyStars(ctx, reducedMotion ? 0 : time / 1000);
      ctx.translate(0, SCENE_DROP);
      ctx.drawImage(image, 0, 0, SCENE_WIDTH, SCENE_HEIGHT);
      patchOriginalMoon(ctx, image);
      drawSmallMoon(ctx);
      patchOriginalTitle(ctx, image);
      patchOriginalButtons(ctx, image);
      drawSceneEffects(ctx, reducedMotion ? 0 : time / 1000, rect.width / rect.height < 0.8);
      ctx.restore();

      if (!reducedMotion) {
        frame = requestAnimationFrame(render);
      }
    };

    const handleResize = () => {
      setSceneHeight();
      if (loaded) {
        render();
      }
    };

    image.onload = () => {
      loaded = true;
      setSceneHeight();
      document.fonts.ready.then(() => render());
    };
    image.src = SOURCE_IMAGE;

    window.addEventListener("resize", handleResize);
    window.visualViewport?.addEventListener("resize", handleResize);

    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("resize", handleResize);
      window.visualViewport?.removeEventListener("resize", handleResize);
    };
  }, []);

  return (
    <>
      <main className="scene" aria-labelledby="drift-title">
        <canvas ref={canvasRef} className="scene-canvas" aria-hidden="true" />

        <section className="scene-ui" aria-label="Try Drift">
          <h1 aria-label="DRIFT" className="scene-title" id="drift-title">
            <span className="scene-title__label">
              <span>D</span>
              <span>R</span>
              <span>I</span>
              <span>F</span>
              <span>T</span>
            </span>
            <span className="scene-title__sparkles" aria-hidden="true">
              <span />
              <span />
              <span />
              <span />
              <span />
              <span />
            </span>
          </h1>

          <TryItLink />
        </section>
      </main>

      <footer className="scene-footer" aria-label="Copyright">
        <span className="scene-footer__copy">© 2026 XINGE XU</span>
        <span className="scene-footer__icons">
          <a
            aria-label="GitHub"
            className="scene-footer__icon scene-footer__icon--github"
            href={GITHUB_REPOSITORY_URL}
            rel="noreferrer"
            target="_blank"
          >
            <BrandLogo mark="github" />
          </a>
          <a
            aria-label="LinkedIn"
            className="scene-footer__icon scene-footer__icon--linkedin"
            href="https://www.linkedin.com/in/xinge-xu-5b4191306/"
            rel="noreferrer"
            target="_blank"
          >
            <BrandLogo mark="linkedin" />
          </a>
          <a
            aria-label="Email Xinge Xu"
            className="scene-footer__icon scene-footer__icon--mail"
            href={EMAIL_COMPOSE_URL}
            rel="noreferrer"
            target="_blank"
          >
            <PixelLogo mark="mail" />
          </a>
        </span>
      </footer>
    </>
  );
}
