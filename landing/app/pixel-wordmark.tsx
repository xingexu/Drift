const pixelSize = 8;
const pixelColumns = 60;
const pixelRows = 12;

// Flat palette colors and irregular dithering keep small cells visibly pixelated.
const pixelPalette = [
  "#ffe4b0", "#ffd39e", "#ffc08f", "#f5ad9c", "#ed9caa",
  "#e58ab7", "#d77dc2", "#c571cb", "#b366d0", "#a35dcb",
  "#9653c5", "#8b49bf", "#8041b7",
];

const pixels = Array.from({ length: pixelColumns * pixelRows }, (_, index) => {
  const column = index % pixelColumns;
  const row = Math.floor(index / pixelColumns);
  const diagonal = .65 * column / (pixelColumns - 1) + .35 * row / (pixelRows - 1);
  const shade = diagonal * (pixelPalette.length - 1);
  const lower = Math.floor(shade);
  const upper = Math.min(lower + 1, pixelPalette.length - 1);
  let seed = Math.imul(column + 1, 374761393) + Math.imul(row + 1, 668265263);
  seed = Math.imul(seed ^ (seed >>> 13), 1274126177);
  const threshold = ((seed ^ (seed >>> 16)) >>> 0) / 4294967296;
  // Mix only adjacent palette shades, without repeating a light/dark checkerboard.
  const color = pixelPalette[threshold < shade - lower ? upper : lower];

  return {
    x: column * pixelSize,
    y: 8 + row * pixelSize,
    color,
  };
});

export default function PixelWordmark() {
  return (
    <svg className="pixel-wordmark" viewBox="-12 0 510 132" aria-hidden="true" focusable="false">
      <defs>
        <text id="drift-letter-face" x="0" y="100" className="pixel-wordmark__type">DRIFT</text>
        <clipPath id="drift-letter-clip"><use href="#drift-letter-face" /></clipPath>
      </defs>
      <g className="pixel-wordmark__depth" strokeWidth="2" strokeLinejoin="miter">
        <use href="#drift-letter-face" transform="translate(7 13)" fill="#301b35" stroke="#301b35" />
        <use href="#drift-letter-face" transform="translate(6 11)" fill="#713c61" stroke="#713c61" />
        <use href="#drift-letter-face" transform="translate(4 8)" fill="#a05c7f" stroke="#a05c7f" />
        <use href="#drift-letter-face" transform="translate(2 4)" fill="#cb85a5" stroke="#edb0ca" />
      </g>
      <use href="#drift-letter-face" fill={pixelPalette[0]} stroke="#fff6ee" strokeWidth="1.5" paintOrder="stroke fill" />
      <g clipPath="url(#drift-letter-clip)">
        <g className="pixel-wordmark__pixels" shapeRendering="crispEdges">
          {pixels.map((pixel, index) => (
            <rect key={index} x={pixel.x} y={pixel.y} width={pixelSize} height={pixelSize}
              fill={pixel.color} />
          ))}
        </g>
        <g className="pixel-wordmark__sweep" fill="#fff4e9" shapeRendering="crispEdges">
          {Array.from({ length: 16 }, (_, index) => (
            <rect key={index} x={24 - index * pixelSize} y={index * pixelSize} width={pixelSize} height={pixelSize} />
          ))}
        </g>
      </g>
      <use href="#drift-letter-face" fill="none" stroke="#fff7f4" strokeWidth="1" opacity=".8" />
    </svg>
  );
}
