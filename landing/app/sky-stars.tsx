// Fixed coordinates keep the server and browser markup identical.
const stars = Array.from({ length: 60 }, (_, index) => {
  const x = ((index * 7919 + 1237) % 19000) / 192 + .5;
  const y = ((index * 3571 + 941) % 5700) / 100 + 1;
  return {
    x,
    y: (x < 8 || x > 92) ? y * .72 : y,
    size: index % 4 === 0 ? 4 : 3,
    duration: 9 + (index % 11),
    delay: -((index * 1.73) % 19),
  };
});

export default function SkyStars() {
  return (
    <div className="sky-stars" aria-hidden="true">
      {stars.map((star, index) => (
        <span
          key={index}
          className={index % 3 === 0 ? "sky-star sky-star--sparkle" : "sky-star"}
          style={{
            left: `${star.x}%`,
            top: `${star.y}%`,
            width: star.size,
            height: star.size,
            animationDuration: `${star.duration}s`,
            animationDelay: `${star.delay}s`,
          }}
        />
      ))}
    </div>
  );
}
