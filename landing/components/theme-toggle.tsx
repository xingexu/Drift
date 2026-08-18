"use client";

import { useTheme } from "./theme-provider";

export function ThemeToggle() {
  const { theme, toggleTheme } = useTheme();
  const nextTheme = theme === "light" ? "night" : "light";

  return (
    <button
      className="theme-btn"
      onClick={toggleTheme}
      aria-label={`Switch to ${nextTheme} theme`}
      type="button"
    >
      <span className={theme === "light" ? "theme-icon moon" : "theme-icon sun"} aria-hidden="true" />
      <span>{nextTheme}</span>
    </button>
  );
}
