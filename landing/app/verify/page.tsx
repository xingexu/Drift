"use client";

import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import Link from "next/link";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

type VerifyState = "loading" | "success" | "error";

export default function VerifyPage() {
  const [state, setState] = useState<VerifyState>("loading");
  const [errorMessage, setErrorMessage] = useState(
    "This verification link is invalid or has expired."
  );

  useEffect(() => {
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { detectSessionInUrl: true },
    });

    async function verify() {
      try {
        const hash = window.location.hash.substring(1);
        const params = new URLSearchParams(hash);

        const accessToken = params.get("access_token");
        const refreshToken = params.get("refresh_token");

        if (accessToken && refreshToken) {
          const { error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });
          if (error) {
            setErrorMessage(error.message);
            setState("error");
            return;
          }
          setState("success");
          return;
        }

        const {
          data: { session },
        } = await supabase.auth.getSession();
        if (session) {
          setState("success");
          return;
        }

        const queryParams = new URLSearchParams(window.location.search);
        const tokenHash = queryParams.get("token_hash");
        const emailType = queryParams.get("type");

        if (tokenHash && emailType) {
          const { error: verifyError } = await supabase.auth.verifyOtp({
            token_hash: tokenHash,
            type: emailType as "email",
          });
          if (verifyError) {
            setErrorMessage(verifyError.message);
            setState("error");
          } else {
            setState("success");
          }
          return;
        }

        setErrorMessage("No verification token found. Please check your email link.");
        setState("error");
      } catch {
        setErrorMessage("Something went wrong. Please try signing in again.");
        setState("error");
      }
    }

    verify();
  }, []);

  return (
    <div className="verify-body">
      <div className="verify-card">
        <div className="verify-logo">drift</div>

        {state === "loading" && (
          <div>
            <div className="spinner" />
            <h1>Verifying your email...</h1>
            <p>Please wait a moment.</p>
          </div>
        )}

        {state === "success" && (
          <div>
            <div className="verify-card-icon">&#10003;</div>
            <h1 className="success">Email verified!</h1>
            <p>
              Your account is now active. You can close this page and return to the Drift extension.
            </p>
            <Link href="/" className="btn">
              Go to Drift
            </Link>
          </div>
        )}

        {state === "error" && (
          <div>
            <div className="verify-card-icon">&#10007;</div>
            <h1 className="error">Verification failed</h1>
            <p>{errorMessage}</p>
            <Link href="/" className="btn">
              Back to Drift
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
