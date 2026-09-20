const pixels = Array.from({ length: 600 }, (_, index) => ({
  x: (index % 60) * 8,
  y: 20 + Math.floor(index / 60) * 8,
  size: 8,
  color: ["#ffe0b4", "#ffe0b4", "#ffdbb9", "#ffd5bf", "#ffcfca", "#ffcad2", "#ffc5dc", "#ffc2e0", "#ffc2e0", "#ffd0e7"][Math.floor(index / 60)],
  delay: -((index % 60) * .06 + Math.floor(index / 60) * .12),
}));

export default function PixelWordmark() {
  return (
    <svg className="pixel-wordmark" viewBox="-12 0 510 132" aria-hidden="true" focusable="false">
      <defs>
        <text id="drift-letter-face" x="0" y="100" className="pixel-wordmark__type">DRIFT</text>
        <clipPath id="drift-letter-clip"><use href="#drift-letter-face" /></clipPath>
        <linearGradient id="drift-peach" x1="0" y1="20" x2="0" y2="102" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#ffe2bd" />
          <stop offset="28%" stopColor="#ffbf91" />
          <stop offset="55%" stopColor="#f5abc0" />
          <stop offset="80%" stopColor="#f0a1ca" />
          <stop offset="100%" stopColor="#ffd0e6" />
        </linearGradient>
      </defs>
      <g className="pixel-wordmark__depth" strokeWidth="2" strokeLinejoin="miter">
        <use href="#drift-letter-face" transform="translate(7 13)" fill="#301b35" stroke="#301b35" />
        <use href="#drift-letter-face" transform="translate(6 11)" fill="#713c61" stroke="#713c61" />
        <use href="#drift-letter-face" transform="translate(4 8)" fill="#a05c7f" stroke="#a05c7f" />
        <use href="#drift-letter-face" transform="translate(2 4)" fill="#cb85a5" stroke="#edb0ca" />
      </g>
      <use href="#drift-letter-face" fill="url(#drift-peach)" stroke="#fff6ee" strokeWidth="1.5" paintOrder="stroke fill" />
      <g clipPath="url(#drift-letter-clip)">
        <g className="pixel-wordmark__pixels" shapeRendering="crispEdges">
          {pixels.map((pixel, index) => (
            <rect key={index} x={pixel.x} y={pixel.y} width={pixel.size} height={pixel.size}
              fill={pixel.color} style={{ animationDelay: `${pixel.delay}s` }} />
          ))}
        </g>
        <g className="pixel-wordmark__sweep" fill="#fff4e9" shapeRendering="crispEdges">
          {Array.from({ length: 14 }, (_, index) => (
            <rect key={index} x={24 - index * 8} y={4 + index * 8} width="8" height="8" />
          ))}
        </g>
      </g>
      <use href="#drift-letter-face" fill="none" stroke="#fff7f4" strokeWidth="1" opacity=".8" />
    </svg>
  );
}
