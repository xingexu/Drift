"use client";

import { useEffect, useRef } from "react";

const SCENE_WIDTH = 3072;
const SCENE_HEIGHT = 2048;
const SOURCE_IMAGE = "/art/drift-original-scene-2x.png";
const SCENE_DROP = 118;

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

function patchOriginalMoon(ctx: PixelContext, image: HTMLImageElement) {
  ctx.drawImage(image, 2040, 240, 620, 500, 2520, 170, 620, 500);
  ctx.globalAlpha = 0.34;
  pixel(ctx, 2540, 300, 160, 36, "#0d061f");
  pixel(ctx, 2790, 380, 180, 44, "#100824");
  pixel(ctx, 2620, 520, 240, 40, "#120927");
  ctx.globalAlpha = 1;
}

function drawSmallMoon(ctx: PixelContext) {
  const x = 2716;
  const y = 258;
  const cells = [
    [4, 0, 6, 1, "#ffe17a"],
    [2, 1, 10, 1, "#ffe987"],
    [1, 2, 12, 1, "#fff0a5"],
    [0, 3, 14, 1, "#fff0a5"],
    [0, 4, 14, 1, "#ffef9f"],
    [0, 5, 14, 1, "#ffef9f"],
    [0, 6, 14, 1, "#ffe78a"],
    [1, 7, 12, 1, "#f5c866"],
    [2, 8, 10, 1, "#efb758"],
    [4, 9, 6, 1, "#d89a46"],
    [12, 2, 1, 5, "#d69a48"],
    [13, 3, 1, 3, "#bc793b"],
    [5, 3, 2, 2, "#d99c4a"],
    [9, 5, 2, 2, "#d99c4a"],
    [11, 4, 1, 2, "#f0c563"],
    [10, 7, 2, 1, "#f4d16f"],
  ];

  for (const [cellX, cellY, cellW, cellH, color] of cells) {
    pixel(ctx, x + Number(cellX) * 12, y + Number(cellY) * 12, Number(cellW) * 12, Number(cellH) * 12, String(color));
  }
}

function drawTitle(ctx: PixelContext) {
  ctx.save();
  ctx.textAlign = "center";
  ctx.textBaseline = "alphabetic";
  ctx.font = '166px "Press Start 2P", monospace';
  ctx.globalAlpha = 0.74;
  ctx.fillStyle = "#4b2544";
  ctx.fillText("DRIFT", 1558, 850);
  ctx.fillStyle = "#8f4d30";
  ctx.fillText("DRIFT", 1548, 834);
  ctx.fillStyle = "#b56c35";
  ctx.fillText("DRIFT", 1540, 818);
  ctx.globalAlpha = 1;
  ctx.fillStyle = "#fff0a5";
  ctx.fillText("DRIFT", 1532, 800);
  ctx.restore();
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

function drawLizard(ctx: PixelContext, elapsed: number) {
  const left = 842;
  const right = 1218;
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

function drawSceneEffects(ctx: PixelContext, elapsed: number) {
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

  drawLizard(ctx, elapsed);
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
      const height = window.visualViewport?.height ?? window.innerHeight;
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
      drawSceneEffects(ctx, reducedMotion ? 0 : time / 1000);
      drawTitle(ctx);
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

        <h1 className="sr-only" id="drift-title">
          DRIFT
        </h1>

        <a
          aria-label="Download Drift for macOS"
          className="download-hotspot download-hotspot-mac"
          href="/downloads/drift-macos.dmg"
        />

        <a
          aria-label="Download Drift for Windows"
          className="download-hotspot download-hotspot-windows"
          href="/downloads/drift-windows.exe"
        />
      </main>

      <footer className="scene-footer" aria-label="Copyright">
        <span className="scene-footer__copy">© 2026 xinge xu</span>
        <span className="scene-footer__icons">
          <a
            aria-label="GitHub"
            className="scene-footer__icon scene-footer__icon--github"
            href="https://github.com/xingexu"
            rel="noreferrer"
            target="_blank"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24">
              <path d="M12 2C6.48 2 2 6.58 2 12.24c0 4.52 2.86 8.35 6.84 9.7.5.1.68-.22.68-.5v-1.75c-2.78.62-3.37-1.37-3.37-1.37-.45-1.18-1.1-1.5-1.1-1.5-.9-.63.07-.62.07-.62 1 .07 1.53 1.05 1.53 1.05.89 1.56 2.34 1.11 2.9.85.09-.66.35-1.11.63-1.37-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.3.1-2.7 0 0 .84-.28 2.75 1.05A9.33 9.33 0 0 1 12 6.93c.85 0 1.7.12 2.5.34 1.9-1.33 2.74-1.05 2.74-1.05.55 1.4.2 2.44.1 2.7.64.72 1.03 1.63 1.03 2.75 0 3.93-2.34 4.8-4.57 5.05.36.32.68.95.68 1.92v2.85c0 .28.18.6.69.5A10.14 10.14 0 0 0 22 12.24C22 6.58 17.52 2 12 2Z" />
            </svg>
          </a>
          <a
            aria-label="LinkedIn"
            className="scene-footer__icon scene-footer__icon--linkedin"
            href="https://www.linkedin.com/in/xinge-xu-5b4191306/"
            rel="noreferrer"
            target="_blank"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24">
              <path d="M4.2 8.8h3.2V20H4.2V8.8Zm1.6-5A1.85 1.85 0 1 1 5.8 7.5a1.85 1.85 0 0 1 0-3.7ZM9.8 8.8H13v1.55h.05c.45-.85 1.55-1.85 3.2-1.85 3.35 0 3.95 2.2 3.95 5.05V20H17v-5.75c0-1.35-.05-3.1-1.9-3.1-1.9 0-2.2 1.45-2.2 3V20H9.8V8.8Z" />
            </svg>
          </a>
          <a
            aria-label="Email"
            className="scene-footer__icon scene-footer__icon--mail"
            href="mailto:xingexu1107@gmail.com"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24">
              <path d="M3 5h18v14H3V5Zm2.2 2v1.4l6.8 4.45 6.8-4.45V7H5.2Zm13.6 10V10.8L12 15.25 5.2 10.8V17h13.6Z" />
            </svg>
          </a>
        </span>
      </footer>
    </>
  );
}
