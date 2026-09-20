import Image from "next/image";
import SceneVideo from "./scene-video";
import PixelWordmark from "./pixel-wordmark";
import SkyStars from "./sky-stars";

const GITHUB_REPOSITORY_URL = "https://github.com/xingexu/Drift";
const TRY_IT_URL = `${GITHUB_REPOSITORY_URL}#try-it-locally`;
const EMAIL_COMPOSE_URL =
  "https://mail.google.com/mail/?view=cm&fs=1&to=xingexu1107%40gmail.com";

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
        aria-label="Open Drift's local setup guide on GitHub"
        className="install-picker__trigger"
        href={TRY_IT_URL}
        rel="noreferrer"
        target="_blank"
      >
        <span>Try it now</span>
        <svg aria-hidden="true" className="install-picker__arrow" focusable="false" viewBox="0 0 16 16">
          <path d="M3 8h9M8.5 4.5 12 8l-3.5 3.5" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" />
        </svg>
      </a>
    </div>
  );
}

export default function Home() {
  return (
    <>
      <main className="scene" aria-labelledby="drift-title">
        <Image
          src="/art/drift-desert-night.png"
          alt=""
          fill
          priority
          unoptimized
          sizes="100vw"
          className="scene-background"
        />
        <SceneVideo />
        <div className="scene-lighting" aria-hidden="true">
          <SkyStars />
          <div className="scene-sun-glow" />
        </div>

        <section className="scene-ui" aria-label="Try Drift">
          <h1 aria-label="DRIFT" className="scene-title" id="drift-title">
            <PixelWordmark />
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
