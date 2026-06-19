"use client";

export function FreePricingBtn() {
  return (
    <a href="https://apps.apple.com" className="pricing-btn pricing-btn-free" style={{ display: "block", textAlign: "center", textDecoration: "none" }}>
      Download free
    </a>
  );
}

export function ProPricingBtn() {
  const open = () => {
    const fn = (window as unknown as Record<string, unknown>).__openAuthModal as
      | ((tab: string) => void)
      | undefined;
    if (fn) fn("signup");
  };
  return (
    <button className="pricing-btn pricing-btn-pro" onClick={open}>
      Get started with Pro
    </button>
  );
}
