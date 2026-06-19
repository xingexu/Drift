"use client";

export function HeroActions() {
  const openSignup = () => {
    const fn = (window as unknown as Record<string, unknown>).__openAuthModal as
      | ((tab: string) => void)
      | undefined;
    if (fn) fn("signup");
  };

  return (
    <div className="hero-actions anim-fade-up anim-fade-up-d3">
      <button className="btn-primary" onClick={openSignup}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
          <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
          <polyline points="7 10 12 15 17 10" />
          <line x1="12" y1="15" x2="12" y2="3" />
        </svg>
        Download for Mac
      </button>
      <a href="#features" className="btn-ghost">
        See how it works
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <line x1="12" y1="5" x2="12" y2="19" />
          <polyline points="19 12 12 19 5 12" />
        </svg>
      </a>
    </div>
  );
}

export function CtaButton() {
  const openSignup = () => {
    const fn = (window as unknown as Record<string, unknown>).__openAuthModal as
      | ((tab: string) => void)
      | undefined;
    if (fn) fn("signup");
  };

  return (
    <button className="btn-primary btn-lg" onClick={openSignup}>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
        <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
        <polyline points="7 10 12 15 17 10" />
        <line x1="12" y1="15" x2="12" y2="3" />
      </svg>
      Download Drift — it&apos;s free
    </button>
  );
}
