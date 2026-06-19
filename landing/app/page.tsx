import Link from "next/link";
import { ThemeToggle } from "@/components/theme-toggle";
import { AuthModal } from "@/components/auth-modal";
import { HeroActions, CtaButton } from "@/components/hero-actions";
import { AnimatedStats } from "@/components/animated-stats";
import { ScrollReveal } from "@/components/scroll-reveal";
import { FreePricingBtn, ProPricingBtn } from "@/components/pricing-ctas";

export default function Home() {
  return (
    <>
      <ScrollReveal />

      {/* ── Nav backdrop ── */}
      <div className="nav-backdrop" aria-hidden />

      {/* ── Navigation ── */}
      <nav>
        <Link className="nav-logo" href="/">
          <span className="nav-logo-dot" aria-hidden />
          drift
        </Link>

        <div className="nav-center">
          <a href="#features" className="nav-link">Features</a>
          <a href="#how" className="nav-link">How it works</a>
          <a href="#pricing" className="nav-link">Pricing</a>
        </div>

        <div className="nav-right">
          <ThemeToggle />
          <AuthModal />
        </div>
      </nav>

      {/* ── Hero ── */}
      <section className="hero">
        <div className="hero-eyebrow anim-fade-up">
          <span className="hero-eyebrow-dot" aria-hidden />
          macOS focus tracker
        </div>
        <h1 className="anim-fade-up anim-fade-up-d1">
          Stop losing hours<br />
          <span className="grad">to distraction.</span>
        </h1>
        <p className="anim-fade-up anim-fade-up-d2">
          Drift tracks every session, spots the moment your focus breaks,
          and shows you exactly where your time went — so you can build habits that last.
        </p>
        <HeroActions />
        <div className="hero-trust anim-fade-up anim-fade-up-d4">
          <span className="hero-trust-item">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 12l2 2 4-4M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            Privacy-first
          </span>
          <span className="hero-trust-item">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 12l2 2 4-4M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            Local storage only
          </span>
          <span className="hero-trust-item">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 12l2 2 4-4M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            Free to start
          </span>
        </div>
      </section>

      {/* ── Product mockup ── */}
      <div className="mockup-wrap" data-reveal>
        <div className="mac-window">
          {/* Title bar */}
          <div className="mac-bar">
            <div className="mac-dots" aria-hidden>
              <span className="mac-dot red" />
              <span className="mac-dot amber" />
              <span className="mac-dot green" />
            </div>
            <span className="mac-bar-title">Drift — Session active</span>
          </div>

          {/* App body */}
          <div className="mac-body">
            {/* Sidebar */}
            <aside className="mac-sidebar" aria-label="App navigation">
              <div className="mac-sidebar-logo">
                <span className="mac-sidebar-logo-icon">D</span>
                <span className="mac-sidebar-logo-name">Drift</span>
              </div>
              {[
                { icon: "⌂", label: "Home" },
                { icon: "◉", label: "Session", active: true },
                { icon: "◷", label: "Focus" },
                { icon: "≡", label: "History" },
                { icon: "⚙", label: "Settings" },
              ].map(({ icon, label, active }) => (
                <div key={label} className={`mac-nav-item${active ? " active" : ""}`}>
                  <span className="nav-icon">{icon}</span>
                  {label}
                </div>
              ))}
              <div className="mac-tracking-badge">
                <span className="mac-tracking-dot" />
                1:24:03 · Tracking
              </div>
            </aside>

            {/* Main content */}
            <main className="mac-content">
              <div className="mac-content-header">
                <span className="mac-content-title">Session</span>
                <div className="mac-live-pill">
                  <span className="mac-live-dot" />
                  LIVE
                </div>
              </div>

              <div className="mac-timer">1:24:03</div>
              <div className="mac-timer-sub">docs.google.com · drifted after 47:12</div>

              <div className="mac-progress">
                <div className="mac-progress-f" style={{ width: "64%" }} />
                <div className="mac-progress-d" style={{ width: "36%" }} />
              </div>

              <div className="mac-stat-row">
                <div className="mac-stat-cell">
                  <div className="mac-stat-val g">47:12</div>
                  <div className="mac-stat-key">Focused</div>
                </div>
                <div className="mac-stat-cell">
                  <div className="mac-stat-val r">26:08</div>
                  <div className="mac-stat-key">Drifted</div>
                </div>
                <div className="mac-stat-cell">
                  <div className="mac-stat-val">37%</div>
                  <div className="mac-stat-key">Drift score</div>
                </div>
                <div className="mac-stat-cell">
                  <div className="mac-stat-val">8</div>
                  <div className="mac-stat-key">Apps</div>
                </div>
              </div>

              <div className="mac-app-rows">
                {[
                  { dot: "g", name: "docs.google.com",  time: "47:12" },
                  { dot: "r", name: "instagram.com",    time: "12:34" },
                  { dot: "r", name: "youtube.com",      time: "8:42" },
                  { dot: "g", name: "github.com",       time: "5:03" },
                  { dot: "n", name: "notion.so",        time: "3:18" },
                ].map((row) => (
                  <div key={row.name} className="mac-app-row">
                    <span className={`mac-app-dot ${row.dot}`} />
                    <span className="mac-app-name">{row.name}</span>
                    <span className="mac-app-time">{row.time}</span>
                  </div>
                ))}
              </div>
            </main>
          </div>
        </div>
      </div>

      {/* ── Stats bar ── */}
      <div className="stats-wrap">
        <AnimatedStats />
      </div>

      {/* ── Features bento ── */}
      <section className="features" id="features">
        <p className="section-eyebrow" data-reveal>What Drift does</p>
        <h2 className="section-title" data-reveal data-delay="1">Built for serious focus</h2>
        <p className="section-sub" data-reveal data-delay="2">
          Simple enough to stay out of your way. Powerful enough to change your habits.
        </p>

        <div className="bento">
          {/* Wide card – session tracking */}
          <div className="bento-card wide" data-reveal>
            <div className="bento-icon">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
              </svg>
            </div>
            <h3>Real-time session tracking</h3>
            <p>
              Start a session and Drift silently records every app switch. See exactly how long
              you spent on each site, when you drifted, and what pulled you away.
            </p>
            <div className="bento-demo-bar">
              <div className="bento-demo-bar-fill-g" style={{ width: "64%" }} />
              <div className="bento-demo-bar-fill-r" style={{ width: "36%" }} />
            </div>
          </div>

          {/* Focus timer */}
          <div className="bento-card" data-reveal data-delay="1">
            <div className="bento-icon">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>
              </svg>
            </div>
            <h3>Focus timer</h3>
            <p>Pomodoro-style focus sessions with customizable work and break intervals.</p>
            <div className="bento-timer-preview">24:38</div>
            <div className="bento-timer-label">Focus session active</div>
          </div>

          {/* Drift detection */}
          <div className="bento-card" data-reveal data-delay="2">
            <div className="bento-icon">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
              </svg>
            </div>
            <h3>Drift detection</h3>
            <p>Know the exact moment focus breaks. Drift flags the switch and logs it.</p>
          </div>

          {/* Site blocking */}
          <div className="bento-card" data-reveal data-delay="3">
            <div className="bento-icon">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
              </svg>
            </div>
            <h3>Site blocking</h3>
            <p>Block distracting sites during focus sessions. Password-protect to make it stick.</p>
          </div>

          {/* Smart categories */}
          <div className="bento-card" data-reveal data-delay="1">
            <div className="bento-icon green">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/>
                <line x1="2" y1="12" x2="22" y2="12"/>
                <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/>
              </svg>
            </div>
            <h3>Smart categories</h3>
            <p>Apps and sites auto-classified as productive, neutral, or distraction. Fully customizable.</p>
            <div className="bento-chips">
              <span className="bento-chip productive">Productive</span>
              <span className="bento-chip neutral">Neutral</span>
              <span className="bento-chip distraction">Distraction</span>
            </div>
          </div>

          {/* History + streaks */}
          <div className="bento-card" data-reveal data-delay="2">
            <div className="bento-icon green">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="20" x2="18" y2="10"/>
                <line x1="12" y1="20" x2="12" y2="4"/>
                <line x1="6" y1="20" x2="6" y2="14"/>
              </svg>
            </div>
            <h3>History &amp; streaks</h3>
            <p>Track focus trends over time. Build streaks and spot patterns in your productivity.</p>
            <div className="bento-mini-streak" aria-hidden>
              {[28, 45, 62, 38, 72, 54, 80].map((h, i) => (
                <div key={i} className={`streak-bar${h > 50 ? " lit" : ""}`} style={{ height: `${h * 0.4}px` }} />
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── How it works ── */}
      <section className="how" id="how">
        <p className="section-eyebrow" data-reveal>Simple by design</p>
        <h2 className="section-title" data-reveal data-delay="1">Three steps to clarity</h2>
        <p className="section-sub" data-reveal data-delay="2">
          No complex setup. No configuration required. Just open Drift and start working.
        </p>
        <div className="how-steps">
          {[
            {
              n: "1",
              title: "Start a session",
              body: "Click once when you sit down to work. Drift begins tracking silently in the background.",
            },
            {
              n: "2",
              title: "Work naturally",
              body: "Switch between apps, browse, write — Drift captures it all without interrupting you.",
            },
            {
              n: "3",
              title: "See the truth",
              body: "When you're done, review exactly where your time went and where you drifted.",
            },
          ].map((step, i) => (
            <div key={step.n} className="how-step" data-reveal data-delay={String(i + 1)}>
              <div className="how-step-num">{step.n}</div>
              <h3>{step.title}</h3>
              <p>{step.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Testimonials ── */}
      <section className="testimonials">
        <p className="section-eyebrow" data-reveal>Real users</p>
        <h2 className="section-title" data-reveal data-delay="1">People who stopped drifting</h2>
        <p className="section-sub" data-reveal data-delay="2" style={{ marginBottom: 40 }}>
          What our users say about building better focus habits.
        </p>
        <div className="testimonials-grid">
          {[
            {
              stars: "★★★★★",
              text: "\"I had no idea how much time I was losing to YouTube. Drift showed me the truth in my first session. Down from 2h of distraction to under 20 minutes.\"",
              initials: "AK",
              name: "Alex K.",
              role: "Software engineer",
            },
            {
              stars: "★★★★★",
              text: "\"The focus timer with site blocking is what I needed. When my most distracting sites are blocked, I'm unstoppable. The streak system keeps me honest.\"",
              initials: "MR",
              name: "Maya R.",
              role: "Product designer",
            },
            {
              stars: "★★★★★",
              text: "\"Simple, beautiful, and it actually works. I review my sessions every evening and it's completely changed how I plan my mornings. Zero fluff.\"",
              initials: "JT",
              name: "James T.",
              role: "Freelance writer",
            },
          ].map((t) => (
            <div key={t.name} className="testimonial-card" data-reveal>
              <div className="testimonial-stars">{t.stars}</div>
              <p className="testimonial-text">{t.text}</p>
              <div className="testimonial-author">
                <div className="testimonial-avatar">{t.initials}</div>
                <div>
                  <div className="testimonial-name">{t.name}</div>
                  <div className="testimonial-role">{t.role}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── Pricing ── */}
      <section className="pricing" id="pricing">
        <p className="section-eyebrow" data-reveal>Simple pricing</p>
        <h2 className="section-title" data-reveal data-delay="1">Free to focus. Pro to go deeper.</h2>
        <p className="section-sub" data-reveal data-delay="2">
          Start for free with everything you need. Upgrade when you want more.
        </p>
        <div className="pricing-cards" data-reveal data-delay="3">
          {/* Free */}
          <div className="pricing-card">
            <div className="pricing-badge free">Free</div>
            <div className="pricing-name">Starter</div>
            <div className="pricing-price">
              <span className="pricing-amount">$0</span>
              <span className="pricing-period">/ forever</span>
            </div>
            <p className="pricing-desc">Everything you need to start tracking your focus.</p>
            <div className="pricing-features">
              {[
                "Session tracking & history",
                "Drift score & focus %",
                "Focus timer (Pomodoro)",
                "Smart app categories",
                "30-day history",
                "Local storage — 100% private",
              ].map((f) => (
                <div key={f} className="pricing-feature">
                  <span className="pricing-check">
                    <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2">
                      <polyline points="2 6 5 9 10 3" />
                    </svg>
                  </span>
                  {f}
                </div>
              ))}
            </div>
            <FreePricingBtn />
          </div>

          {/* Pro */}
          <div className="pricing-card featured">
            <div className="pricing-badge">Pro</div>
            <div className="pricing-name">Pro</div>
            <div className="pricing-price">
              <span className="pricing-amount">$7</span>
              <span className="pricing-period">/ month</span>
            </div>
            <p className="pricing-desc">For people serious about understanding their focus.</p>
            <div className="pricing-features">
              {[
                "Everything in Starter",
                "Unlimited history",
                "Advanced analytics & trends",
                "Site blocking (password-protected)",
                "Cloud sync across Macs",
                "Weekly focus reports",
                "Priority support",
              ].map((f) => (
                <div key={f} className="pricing-feature">
                  <span className="pricing-check">
                    <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2">
                      <polyline points="2 6 5 9 10 3" />
                    </svg>
                  </span>
                  {f}
                </div>
              ))}
            </div>
            <ProPricingBtn />
          </div>
        </div>
      </section>

      {/* ── CTA band ── */}
      <div className="cta-band" data-reveal>
        <div className="cta-card">
          <h2>Ready to stop drifting?</h2>
          <p>Download Drift for Mac — free forever. No account required to start.</p>
          <CtaButton />
          <div className="cta-trust">
            <span className="cta-trust-item">✓ Free to download</span>
            <span className="cta-trust-item">✓ No account required</span>
            <span className="cta-trust-item">✓ No data collection</span>
          </div>
        </div>
      </div>

      {/* ── Footer ── */}
      <footer>
        <div className="footer-left">
          <span className="f-logo">drift</span>
          <span className="f-copy">© {new Date().getFullYear()} Drift. All rights reserved.</span>
        </div>
        <div className="f-links">
          <a href="#" className="f-link">Privacy</a>
          <a href="#" className="f-link">GitHub</a>
          <a href="#" className="f-link">Support</a>
        </div>
      </footer>
    </>
  );
}
