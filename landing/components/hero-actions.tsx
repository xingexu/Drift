"use client";

export function HeroActions() {
  const handleGetStarted = () => {
    const openModal = (window as unknown as Record<string, unknown>).__openAuthModal as
      | ((tab: string) => void)
      | undefined;
    if (openModal) openModal("signup");
  };

  return (
    <div className="anim-fade-up anim-fade-up-d3" style={{ display: "flex", justifyContent: "center", gap: 12, flexWrap: "wrap" }}>
      <button className="btn-primary" onClick={handleGetStarted}>
        Get started
      </button>
      <a href="https://chrome.google.com/webstore" target="_blank" rel="noopener noreferrer" className="btn-chrome">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
          <polyline points="7 10 12 15 17 10" />
          <line x1="12" y1="15" x2="12" y2="3" />
        </svg>
        Add to Chrome
      </a>
    </div>
  );
}

export function CtaButton() {
  const handleGetStarted = () => {
    const openModal = (window as unknown as Record<string, unknown>).__openAuthModal as
      | ((tab: string) => void)
      | undefined;
    if (openModal) openModal("signup");
  };

  return (
    <button className="btn-primary" onClick={handleGetStarted}>
      Get started
    </button>
  );
}
