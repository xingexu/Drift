"use client";

import { useState, useEffect, useCallback, FormEvent } from "react";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "/api";

type AuthTab = "login" | "signup";

interface User {
  name?: string;
  email: string;
}

export function AuthModal() {
  const [isOpen, setIsOpen] = useState(false);
  const [tab, setTab] = useState<AuthTab>("login");
  const [error, setError] = useState("");
  const [successMessage, setSuccessMessage] = useState<{ title: string; body: string } | null>(null);
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    const existing = localStorage.getItem("drift_user");
    if (existing) {
      try {
        setUser(JSON.parse(existing));
      } catch {}
    }
  }, []);

  const openModal = useCallback((t: AuthTab) => {
    setTab(t);
    setError("");
    setSuccessMessage(null);
    setIsOpen(true);
  }, []);

  const closeModal = useCallback(() => setIsOpen(false), []);

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeModal();
    };
    document.addEventListener("keydown", handleEsc);
    return () => document.removeEventListener("keydown", handleEsc);
  }, [closeModal]);

  // Expose openModal globally for CTA buttons
  useEffect(() => {
    (window as unknown as Record<string, unknown>).__openAuthModal = openModal;
    return () => {
      delete (window as unknown as Record<string, unknown>).__openAuthModal;
    };
  }, [openModal]);

  const handleLogout = () => {
    const rt = localStorage.getItem("drift_refresh_token");
    if (rt) {
      fetch(`${API_URL}/auth/logout`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: rt }),
      }).catch(() => {});
    }
    localStorage.removeItem("drift_access_token");
    localStorage.removeItem("drift_refresh_token");
    localStorage.removeItem("drift_user");
    setUser(null);
  };

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const form = e.currentTarget;
    const email = (form.elements.namedItem("email") as HTMLInputElement).value;
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;
    const name = (form.elements.namedItem("name") as HTMLInputElement)?.value;

    setLoading(true);
    setError("");

    try {
      if (tab === "signup") {
        const res = await fetch(`${API_URL}/auth/signup`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email, password, name: name || undefined }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.message || "Signup failed");
        setSuccessMessage({
          title: "Check your email",
          body: `We sent a verification link to ${email}. Click it to activate your account.`,
        });
      } else {
        const res = await fetch(`${API_URL}/auth/login`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email, password }),
        });
        const data = await res.json();
        if (!res.ok) {
          if (data.code === "EMAIL_NOT_VERIFIED") {
            setSuccessMessage({
              title: "Verify your email",
              body: "Check your inbox and click the verification link before logging in.",
            });
            return;
          }
          throw new Error(data.message || "Login failed");
        }
        localStorage.setItem("drift_access_token", data.accessToken);
        localStorage.setItem("drift_refresh_token", data.refreshToken);
        localStorage.setItem("drift_user", JSON.stringify(data.user));
        setUser(data.user);
        closeModal();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      {/* Nav CTA button */}
      {user ? (
        <button className="nav-cta" onClick={handleLogout} title="Click to log out">
          {user.name || user.email.split("@")[0]}
        </button>
      ) : (
        <button className="nav-cta" onClick={() => openModal("login")}>
          Log in
        </button>
      )}

      {/* Modal */}
      <div
        className={`modal-overlay${isOpen ? " show" : ""}`}
        onClick={(e) => { if (e.target === e.currentTarget) closeModal(); }}
      >
        <div className="modal">
          <button className="modal-close" onClick={closeModal}>
            &times;
          </button>

          {successMessage ? (
            <>
              <h2>{successMessage.title}</h2>
              <div className="auth-success">
                <div className="auth-success-icon">&#9993;</div>
                <h3>{successMessage.title}</h3>
                <p>{successMessage.body}</p>
              </div>
            </>
          ) : (
            <>
              <h2>{tab === "login" ? "Welcome back" : "Create account"}</h2>
              <p className="modal-sub">
                {tab === "login" ? "Log in to sync your data" : "Sign up to sync across devices"}
              </p>

              <div className="modal-tabs">
                <button
                  className={`modal-tab${tab === "login" ? " active" : ""}`}
                  onClick={() => { setTab("login"); setError(""); }}
                >
                  Log in
                </button>
                <button
                  className={`modal-tab${tab === "signup" ? " active" : ""}`}
                  onClick={() => { setTab("signup"); setError(""); }}
                >
                  Sign up
                </button>
              </div>

              {error && <div className="auth-error">{error}</div>}

              <form onSubmit={handleSubmit}>
                {tab === "signup" && (
                  <div className="form-group">
                    <label className="form-label">Name</label>
                    <input className="form-input" type="text" name="name" placeholder="Your name" />
                  </div>
                )}
                <div className="form-group">
                  <label className="form-label">Email</label>
                  <input className="form-input" type="email" name="email" placeholder="you@example.com" required />
                </div>
                <div className="form-group">
                  <label className="form-label">Password</label>
                  <input className="form-input" type="password" name="password" placeholder="&#8226;&#8226;&#8226;&#8226;&#8226;&#8226;&#8226;&#8226;" required />
                </div>
                <button type="submit" className="form-submit" disabled={loading}>
                  {loading
                    ? tab === "signup" ? "Creating..." : "Logging in..."
                    : tab === "signup" ? "Create account" : "Log in"
                  }
                </button>
              </form>

              <div className="form-divider">or</div>

              <button className="form-oauth" onClick={() => setError("Google sign-in coming soon.")}>
                <svg width="16" height="16" viewBox="0 0 24 24">
                  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" />
                  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                </svg>
                Continue with Google
              </button>

              <div className="form-footer">
                {tab === "login" ? (
                  <>Don&apos;t have an account?{" "}<a href="#" onClick={(e) => { e.preventDefault(); setTab("signup"); }}>Sign up</a></>
                ) : (
                  <>Already have an account?{" "}<a href="#" onClick={(e) => { e.preventDefault(); setTab("login"); }}>Log in</a></>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}
