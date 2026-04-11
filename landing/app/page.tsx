import Link from "next/link";
import { ThemeToggle } from "@/components/theme-toggle";
import { AuthModal } from "@/components/auth-modal";
import { HeroActions, CtaButton } from "@/components/hero-actions";

export default function Home() {
  return (
    <>
      <nav>
        <Link className="nav-logo" href="/">
          drift
        </Link>
        <div className="nav-right">
          <a href="#features" className="nav-link">
            Features
          </a>
          <ThemeToggle />
          <AuthModal />
        </div>
      </nav>

      <section className="hero">
        <h1 className="anim-fade-up anim-fade-up-d1">Know where your time goes</h1>
        <p className="anim-fade-up anim-fade-up-d2">
          Drift tracks your browsing sessions and shows exactly when you lose focus. No judgment, just clarity.
        </p>
        <HeroActions />
      </section>

      <div className="demo-wrap">
        <div className="demo">
          <div className="demo-hdr">
            <span className="demo-logo">drift</span>
            <span className="demo-dot" />
          </div>
          <div className="demo-time">1:24:03</div>
          <div className="demo-sub">docs.google.com &middot; drifted after 47:12</div>
          <div className="demo-bar">
            <div className="f" style={{ width: "64%" }} />
            <div className="d" style={{ width: "36%" }} />
          </div>
          <div className="demo-stats">
            <div className="demo-stat">
              <div className="demo-stat-num g">47:12</div>
              <div className="demo-stat-label">Focused</div>
            </div>
            <div className="demo-stat">
              <div className="demo-stat-num r">26:08</div>
              <div className="demo-stat-label">Drifted</div>
            </div>
            <div className="demo-stat">
              <div className="demo-stat-num">37%</div>
              <div className="demo-stat-label">Drift</div>
            </div>
            <div className="demo-stat">
              <div className="demo-stat-num">8</div>
              <div className="demo-stat-label">Sites</div>
            </div>
          </div>
          <div className="demo-rows">
            <div className="demo-row">
              <div className="demo-row-dot r" />
              <span className="demo-row-name">instagram.com</span>
              <span className="demo-row-t">12:34</span>
            </div>
            <div className="demo-row">
              <div className="demo-row-dot r" />
              <span className="demo-row-name">youtube.com</span>
              <span className="demo-row-t">8:42</span>
            </div>
            <div className="demo-row">
              <div className="demo-row-dot g" />
              <span className="demo-row-name">docs.google.com</span>
              <span className="demo-row-t">47:12</span>
            </div>
            <div className="demo-row">
              <div className="demo-row-dot g" />
              <span className="demo-row-name">github.com</span>
              <span className="demo-row-t">5:03</span>
            </div>
          </div>
        </div>
      </div>

      <section className="features" id="features">
        <div className="features-hdr">
          <h2>Built for self-awareness</h2>
          <p>Simple tools that help you understand your browsing habits.</p>
        </div>
        <div className="features-grid">
          <div className="f-card">
            <div className="f-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
            </div>
            <h3>Session tracking</h3>
            <p>Start and end sessions manually. Each one captures every tab switch and page visit.</p>
          </div>
          <div className="f-card">
            <div className="f-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
                <line x1="12" y1="9" x2="12" y2="13" />
                <line x1="12" y1="17" x2="12.01" y2="17" />
              </svg>
            </div>
            <h3>Drift detection</h3>
            <p>Flags the moment you leave productive sites for distractions. See where focus breaks.</p>
          </div>
          <div className="f-card">
            <div className="f-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="20" x2="18" y2="10" />
                <line x1="12" y1="20" x2="12" y2="4" />
                <line x1="6" y1="20" x2="6" y2="14" />
              </svg>
            </div>
            <h3>Weekly reports</h3>
            <p>Aggregated insights across sessions. Track focus trends and top time sinks.</p>
          </div>
          <div className="f-card">
            <div className="f-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0110 0v4" />
              </svg>
            </div>
            <h3>100% private</h3>
            <p>All data stays in your browser. Nothing is sent to any server. Ever.</p>
          </div>
          <div className="f-card">
            <div className="f-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <line x1="2" y1="12" x2="22" y2="12" />
                <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z" />
              </svg>
            </div>
            <h3>Smart categories</h3>
            <p>Sites auto-classified as productive, neutral, or distracting based on domain.</p>
          </div>
          <div className="f-card">
            <div className="f-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
              </svg>
            </div>
            <h3>Session history</h3>
            <p>Review past sessions anytime. Compare drift scores and spot patterns.</p>
          </div>
        </div>
      </section>

      <div className="cta-band">
        <div className="cta-card">
          <h2>Start understanding your time</h2>
          <p>Free Chrome extension. No account required to start tracking.</p>
          <CtaButton />
        </div>
      </div>

      <footer>
        <span className="f-logo">drift</span>
        <div className="f-links">
          <a href="#" className="f-link">Privacy</a>
          <a href="#" className="f-link">GitHub</a>
          <a href="#" className="f-link">Chrome Web Store</a>
        </div>
      </footer>
    </>
  );
}
