export default function PixelWordmark() {
  return (
    <span className="pixel-wordmark" aria-hidden="true">
      {[..."DRIFT"].map((letter, index) => (
        <span
          key={letter}
          className="pixel-wordmark__letter"
          data-letter={letter}
          style={{ animationDelay: `${index * 140 + 500}ms` }}
        >
          {letter}
        </span>
      ))}
    </span>
  );
}
