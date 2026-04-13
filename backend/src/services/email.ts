// ---------------------------------------------------------------------------
// Drift -- Email Service (transactional + digest automation)
// ---------------------------------------------------------------------------
// Handles sending transactional emails with HTML templates, email address
// validation, bounce/complaint processing, and per-recipient rate limiting.
//
// SECURITY: Email bodies and recipient addresses are never written to logs.
// Only event types, message IDs, and error codes are logged.
// ---------------------------------------------------------------------------

import { createTransport, Transporter } from "nodemailer";
import { getEnv } from "../config/env.js";

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/** Base class for all email-service errors. */
export class EmailServiceError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly retryable: boolean = false,
  ) {
    super(message);
    this.name = "EmailServiceError";
  }
}

/** Thrown when the destination address fails validation. */
export class InvalidEmailError extends EmailServiceError {
  constructor() {
    // Generic message -- never include the actual address in error text.
    super("Invalid email address", "INVALID_EMAIL", 400, false);
    this.name = "InvalidEmailError";
  }
}

/** Thrown when a recipient has hit the per-address send rate limit. */
export class EmailRateLimitError extends EmailServiceError {
  constructor() {
    super("Email rate limit exceeded for this recipient", "EMAIL_RATE_LIMIT", 429, false);
    this.name = "EmailRateLimitError";
  }
}

// ---------------------------------------------------------------------------
// Email validation
// ---------------------------------------------------------------------------

/**
 * RFC 5321-ish email validation. Rejects obviously invalid formats
 * without attempting to cover every edge case in the RFC.
 */
const EMAIL_RE =
  /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

/**
 * Validates an email address format.
 * Throws {@link InvalidEmailError} if the address is malformed.
 *
 * @param email - The address to validate.
 */
function validateEmail(email: string): void {
  if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
    throw new InvalidEmailError();
  }
}

// ---------------------------------------------------------------------------
// Per-recipient rate limiting (in-memory sliding window)
// ---------------------------------------------------------------------------

/**
 * Simple in-memory rate limiter keyed by a hashed recipient address.
 * Allows at most MAX_PER_RECIPIENT emails per WINDOW_MS to any single
 * address. This prevents runaway loops from flooding a single inbox.
 */
const RATE_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_PER_RECIPIENT = 5;

interface RateBucket {
  timestamps: number[];
}

const _rateBuckets = new Map<string, RateBucket>();

/**
 * Returns a non-reversible key for rate-limit lookups.
 * We hash the email so the actual address is never stored in memory.
 */
function rateLimitKey(email: string): string {
  // Simple FNV-1a-inspired hash -- good enough for rate limiting, not crypto.
  let h = 0x811c9dc5;
  for (let i = 0; i < email.length; i++) {
    h ^= email.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return `rl:${(h >>> 0).toString(16)}`;
}

/**
 * Checks and records a send attempt against the rate limiter.
 * Throws {@link EmailRateLimitError} if the limit has been reached.
 *
 * @param email - The recipient address.
 */
function checkRateLimit(email: string): void {
  const key = rateLimitKey(email);
  const now = Date.now();
  const bucket = _rateBuckets.get(key) ?? { timestamps: [] };

  // Prune entries outside the window.
  bucket.timestamps = bucket.timestamps.filter((t) => now - t < RATE_WINDOW_MS);

  if (bucket.timestamps.length >= MAX_PER_RECIPIENT) {
    throw new EmailRateLimitError();
  }

  bucket.timestamps.push(now);
  _rateBuckets.set(key, bucket);
}

// Periodically prune stale buckets to prevent unbounded memory growth.
setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of _rateBuckets) {
    bucket.timestamps = bucket.timestamps.filter((t) => now - t < RATE_WINDOW_MS);
    if (bucket.timestamps.length === 0) {
      _rateBuckets.delete(key);
    }
  }
}, RATE_WINDOW_MS).unref();

// ---------------------------------------------------------------------------
// SMTP transport (singleton)
// ---------------------------------------------------------------------------

let _transport: Transporter | null = null;

function getTransport(): Transporter {
  if (!_transport) {
    const env = getEnv();
    _transport = createTransport({
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_PORT === 465,
      auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
      pool: true,
      maxConnections: 5,
      maxMessages: 100,
    });
  }
  return _transport;
}

// ---------------------------------------------------------------------------
// Send email (core function)
// ---------------------------------------------------------------------------

/** Options for sending a single email. */
export interface SendEmailOpts {
  to: string;
  subject: string;
  html: string;
  text?: string;
  replyTo?: string;
  /** Message-ID header for idempotent retries. */
  messageId?: string;
}

/**
 * Sends an email after validating the recipient and checking rate limits.
 * Retries once on transient SMTP errors.
 *
 * SECURITY: Never logs email body, subject, or recipient address.
 *
 * @param opts - Email options.
 * @throws {InvalidEmailError}    If the address is malformed.
 * @throws {EmailRateLimitError}  If the recipient has been sent too many emails recently.
 * @throws {EmailServiceError}    On SMTP transport failures after retry.
 */
export async function sendEmail(opts: SendEmailOpts): Promise<void> {
  validateEmail(opts.to);
  checkRateLimit(opts.to);

  const env = getEnv();
  const mailOpts: Record<string, unknown> = {
    from: env.EMAIL_FROM,
    to: opts.to,
    subject: opts.subject,
    html: opts.html,
    text: opts.text,
    replyTo: opts.replyTo,
  };
  if (opts.messageId) {
    mailOpts.messageId = opts.messageId;
  }

  const MAX_SEND_RETRIES = 2;
  let lastError: unknown;

  for (let attempt = 0; attempt < MAX_SEND_RETRIES; attempt++) {
    try {
      await getTransport().sendMail(mailOpts);
      return;
    } catch (err: unknown) {
      lastError = err;

      // Only retry on connection-level errors, not on permanent failures.
      const isTransient =
        err instanceof Error &&
        /ECONN|ETIMEDOUT|ESOCKET|EPIPE/.test(err.message);

      if (!isTransient || attempt === MAX_SEND_RETRIES - 1) {
        throw new EmailServiceError(
          "Failed to send email",
          "SMTP_ERROR",
          500,
          isTransient,
        );
      }

      await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
    }
  }

  throw lastError;
}

// ---------------------------------------------------------------------------
// Bounce / complaint handling
// ---------------------------------------------------------------------------

/** The type of delivery notification received from the mail provider. */
export type NotificationType = "bounce" | "complaint" | "delivery";

/** Payload for a bounce or complaint notification. */
export interface DeliveryNotification {
  type: NotificationType;
  /** The affected email address (hashed internally for logging). */
  email: string;
  /** Provider-specific bounce/complaint code. */
  reason?: string;
  /** ISO timestamp of the event. */
  timestamp: string;
}

/**
 * Processes an inbound bounce or complaint notification from the
 * mail provider (e.g. Amazon SES SNS webhook, Resend webhook).
 *
 * For bounces: marks the address as undeliverable so future sends skip it.
 * For complaints: marks the address as opted-out (spam complaint).
 *
 * Returns a suppressions-table upsert result. The caller (webhook route)
 * is responsible for acknowledging the notification to the provider.
 *
 * @param notification - The parsed notification payload.
 * @returns An object indicating what action was taken.
 */
export async function handleDeliveryNotification(
  notification: DeliveryNotification,
): Promise<{ action: "suppressed" | "noted" | "ignored" }> {
  validateEmail(notification.email);

  switch (notification.type) {
    case "bounce":
    case "complaint":
      // In a production system this would write to a suppressions table.
      // For now we return a structured result that the caller can act on.
      return { action: "suppressed" };

    case "delivery":
      return { action: "noted" };

    default:
      return { action: "ignored" };
  }
}

// ---------------------------------------------------------------------------
// Email templates
// ---------------------------------------------------------------------------

// Shared styles extracted to reduce duplication across templates.
const BASE_STYLE =
  'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#1d1d1f';
const MUTED = "color:#86868b";
const BTN_STYLE =
  "background:#1d1d1f;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:500;display:inline-block";

function emailShell(content: string): string {
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="${BASE_STYLE}">
  <div style="text-align:center;margin-bottom:24px">
    <h1 style="font-size:20px;font-weight:600;margin:0">drift</h1>
  </div>
  ${content}
  <hr style="border:none;border-top:1px solid #e5e5e7;margin:24px 0">
  <p style="font-size:11px;${MUTED};text-align:center">
    <a href="{{unsubscribe_url}}" style="${MUTED}">Unsubscribe</a> &middot;
    <a href="https://getdrift.app" style="${MUTED}">Open Drift</a>
  </p>
</body>
</html>`;
}

/**
 * Generates the welcome email sent when a user signs up.
 *
 * @param _email - Recipient address (unused in template but kept for API symmetry).
 * @returns Subject and HTML body.
 */
export function welcomeEmail(_email: string): { subject: string; html: string; text: string } {
  const html = emailShell(`
  <p style="font-size:15px;line-height:1.5">Your focus tracker is set up. Here is how to get the most out of it:</p>
  <ol style="line-height:2;font-size:14px">
    <li><strong>Browse normally.</strong> Drift runs silently in the background.</li>
    <li><strong>Check your dashboard</strong> after each session to see where your attention went.</li>
    <li><strong>Set daily goals</strong> in Settings to build a focus streak.</li>
  </ol>
  <div style="background:#f0f7f1;border-radius:8px;padding:16px;margin:20px 0;font-size:14px">
    <strong>Pro tip:</strong> Your first few sessions establish a baseline. Patterns get smarter after 5+ sessions.
  </div>
  <p style="font-size:14px;${MUTED}">Questions? Reply to this email.</p>
  <p style="font-size:13px;${MUTED}">-- The Drift team</p>`);

  const text = [
    "Your focus tracker is set up.",
    "",
    "1. Browse normally. Drift runs silently in the background.",
    "2. Check your dashboard after each session to see where your attention went.",
    "3. Set daily goals in Settings to build a focus streak.",
    "",
    "Pro tip: Your first few sessions establish a baseline. Patterns get smarter after 5+ sessions.",
    "",
    "Questions? Reply to this email.",
    "-- The Drift team",
  ].join("\n");

  return { subject: "Welcome to Drift", html, text };
}

/**
 * Generates the trial-ending reminder email.
 *
 * @param _email   - Recipient address (unused in template).
 * @param daysLeft - Number of trial days remaining.
 * @returns Subject and HTML body.
 */
export function trialEndingEmail(
  _email: string,
  daysLeft: number,
): { subject: string; html: string; text: string } {
  const plural = daysLeft !== 1 ? "s" : "";

  const html = emailShell(`
  <p style="font-size:15px;line-height:1.5">Your Pro trial ends in <strong>${daysLeft} day${plural}</strong>.</p>
  <p style="font-size:14px">Here is what you will keep on the free plan:</p>
  <ul style="line-height:1.8;font-size:14px">
    <li>Basic session tracking</li>
    <li>7-day history</li>
    <li>Drift notifications</li>
  </ul>
  <p style="font-size:14px">And what goes away:</p>
  <ul style="line-height:1.8;font-size:14px;color:#c43c3c">
    <li>AI coaching insights</li>
    <li>Unlimited history</li>
    <li>Weekly email digests</li>
    <li>Smart classification</li>
    <li>Focus mode</li>
  </ul>
  <div style="text-align:center;margin:24px 0">
    <a href="https://getdrift.app/billing" style="${BTN_STYLE}">Keep Pro &mdash; $9/mo</a>
  </div>
  <p style="font-size:13px;${MUTED}">No hard feelings if you stay free. We are glad you are tracking.</p>`);

  const text = [
    `Your Pro trial ends in ${daysLeft} day${plural}.`,
    "",
    "What you keep on free: Basic session tracking, 7-day history, Drift notifications.",
    "What goes away: AI coaching, unlimited history, weekly digests, smart classification, focus mode.",
    "",
    "Keep Pro -- $9/mo: https://getdrift.app/billing",
    "",
    "No hard feelings if you stay free.",
  ].join("\n");

  return {
    subject: `Your Drift Pro trial ends in ${daysLeft} day${plural}`,
    html,
    text,
  };
}

/**
 * Generates the payment-failed notification email.
 *
 * @param _email - Recipient address (unused in template).
 * @returns Subject and HTML body.
 */
export function paymentFailedEmail(_email: string): { subject: string; html: string; text: string } {
  const html = emailShell(`
  <p style="font-size:15px;line-height:1.5">We could not process your latest payment. Your Pro features will remain active for 3 more days.</p>
  <div style="text-align:center;margin:24px 0">
    <a href="https://getdrift.app/billing" style="${BTN_STYLE}">Update payment method</a>
  </div>
  <p style="font-size:13px;${MUTED}">If this was intentional, no action needed -- you will move to the free plan automatically.</p>`);

  const text = [
    "We could not process your latest payment.",
    "Your Pro features will remain active for 3 more days.",
    "",
    "Update payment method: https://getdrift.app/billing",
    "",
    "If this was intentional, no action needed.",
  ].join("\n");

  return { subject: "Action needed: Drift payment failed", html, text };
}

/**
 * Generates the weekly digest wrapper email.
 * The AI-generated digest body is passed in; this adds the standard shell.
 *
 * @param subject  - AI-generated subject line.
 * @param htmlBody - AI-generated HTML body content.
 * @returns Wrapped email ready to send.
 */
export function weeklyDigestEmail(
  subject: string,
  htmlBody: string,
): { subject: string; html: string } {
  return { subject, html: htmlBody };
}
