#!/usr/bin/env node
// Generate PNG icons from the Drift app icon

const fs = require("fs");
const path = require("path");

let sharp;
try {
  sharp = require("sharp");
} catch {
  console.error("sharp not installed. Run: npm install --save-dev sharp");
  process.exit(1);
}

// Rounded square with a stylized "d" and an offset accent dot
const SVG = Buffer.from(`<svg width="128" height="128" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="128" height="128" rx="28" fill="#1a1a1f"/>
  <text x="34" y="92" font-family="Inter, Helvetica, Arial, sans-serif" font-size="72" font-weight="700" fill="#ececef">d</text>
  <circle cx="86" cy="32" r="8" fill="#6c8cff"/>
</svg>`);

const SIZES = [16, 32, 48, 128];
const OUT_DIR = path.resolve(__dirname, "..", "public", "icons");

async function main() {
  if (!fs.existsSync(OUT_DIR)) {
    fs.mkdirSync(OUT_DIR, { recursive: true });
  }

  for (const size of SIZES) {
    const outPath = path.join(OUT_DIR, `icon-${size}.png`);
    await sharp(SVG).resize(size, size).png().toFile(outPath);
    console.log(`  icon-${size}.png`);
  }
  console.log("Icons generated.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
