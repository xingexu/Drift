// ---------------------------------------------------------------------------
// Drift -- AI Coaching Engine (powered by Claude)
// ---------------------------------------------------------------------------
// Provides post-session coaching, weekly digests, and domain classification.
// Includes plan-tier token limits, response caching, content moderation,
// streaming support, and structured error handling.
// ---------------------------------------------------------------------------

import Anthropic from "@anthropic-ai/sdk";
import crypto from "node:crypto";
import { getEnv } from "../config/env.js";
import { getSupabaseAdmin } from "../config/supabase.js";
import { PlanId, getPlan } from "../config/plans.js";

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/** Base class for all AI-service errors. */
export class AIServiceError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly retryable: boolean = false,
  ) {
    super(message);
    this.name = "AIServiceError";
  }
}

/** Thrown when a user has exceeded their plan's daily token budget. */
export class TokenLimitExceededError extends AIServiceError {
  constructor(plan: PlanId) {
    super(
      `Daily AI coaching limit reached for the ${plan} plan`,
      "TOKEN_LIMIT_EXCEEDED",
      429,
      false,
    );
    this.name = "TokenLimitExceededError";
  }
}

/** Thrown when user input fails the content moderation check. */
export class ContentModerationError extends AIServiceError {
  constructor() {
    super(
      "Input contains content that cannot be processed",
      "CONTENT_MODERATION",
      400,
      false,
    );
    this.name = "ContentModerationError";
  }
}

// ---------------------------------------------------------------------------
// Anthropic client (singleton)
// ---------------------------------------------------------------------------

let _client: Anthropic | null = null;

function claude(): Anthropic {
  if (!_client) {
    _client = new Anthropic({ apiKey: getEnv().ANTHROPIC_API_KEY });
  }
  return _client;
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Role for a message in a conversation with Claude. */
export type MessageRole = "user" | "assistant";

/** A single message in a coaching conversation. */
export interface CoachMessage {
  role: MessageRole;
  content: string;
}

/** Browsing session telemetry sent from the extension. */
export interface SessionData {
  totalDurationMs: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  driftScore: number;
  driftPointCount: number;
  topDomains: { domain: string; timeMs: number }[];
  driftPoints: { reason: string; trigger: string; timestamp: number }[];
  entryDomain: string;
  exitDomain: string;
  categorySwitchCount: number;
  longestProductiveStreakMs: number;
  longestDistractionStreakMs: number;
}

/** Structured coaching response returned to the client. */
export interface CoachingResponse {
  summary: string;
  score: "great" | "good" | "okay" | "needs_work";
  keyInsight: string;
  actionItems: string[];
  encouragement: string;
  pattern?: string;
  tokensUsed: { input: number; output: number };
}

/** Weekly digest telemetry aggregated by the backend. */
export interface WeeklyDigestData {
  weekStart: string;
  weekEnd: string;
  sessionCount: number;
  totalTimeMs: number;
  productiveTimeMs: number;
  distractionTimeMs: number;
  averageDriftScore: number;
  topDomains: { domain: string; timeMs: number }[];
  bestDay: { date: string; driftScore: number } | null;
  worstDay: { date: string; driftScore: number } | null;
  previousWeekAvgDrift: number | null;
}

/** Domain classification result. */
export interface DomainClassification {
  category: "productive" | "neutral" | "distraction";
  confidence: number;
  reason: string;
}

/** A streaming coaching event emitted chunk-by-chunk. */
export interface StreamingCoachEvent {
  type: "text_delta" | "complete" | "error";
  delta?: string;
  coaching?: CoachingResponse;
  error?: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Maximum daily token budget per plan tier (input + output). */
const DAILY_TOKEN_LIMITS: Record<PlanId, number> = {
  free: 0,
  pro: 100_000,
  team: 250_000,
};

/** In-memory cache TTL in milliseconds (10 minutes). */
const CACHE_TTL_MS = 10 * 60 * 1000;

/** Maximum entries in the in-memory response cache. */
const MAX_CACHE_ENTRIES = 200;

// ---------------------------------------------------------------------------
// Content moderation
// ---------------------------------------------------------------------------

/** Regex patterns that indicate content we should not process. */
const MODERATION_PATTERNS = [
  // Prompt injection attempts
  /ignore\s+(previous|all|above)\s+(instructions?|prompts?)/i,
  /you\s+are\s+now\s+(?:a\s+)?(?:DAN|evil|unrestricted)/i,
  /system\s*:\s*you/i,
  /\bdo\s+anything\s+now\b/i,
  /jailbreak/i,
];

/**
 * Checks user-provided content for disallowed patterns.
 * Throws {@link ContentModerationError} if any are found.
 */
function moderateContent(text: string): void {
  for (const pattern of MODERATION_PATTERNS) {
    if (pattern.test(text)) {
      throw new ContentModerationError();
    }
  }
}

// ---------------------------------------------------------------------------
// In-memory response cache
// ---------------------------------------------------------------------------

interface CacheEntry {
  value: DomainClassification;
  expiresAt: number;
}

const _classificationCache = new Map<string, CacheEntry>();

function cacheKey(domain: string, title?: string): string {
  const raw = title ? `${domain}::${title}` : domain;
  return crypto.createHash("sha256").update(raw).digest("hex").slice(0, 32);
}

function getCached(key: string): DomainClassification | null {
  const entry = _classificationCache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    _classificationCache.delete(key);
    return null;
  }
  return entry.value;
}

function setCache(key: string, value: DomainClassification): void {
  // Evict oldest entries if over capacity.
  if (_classificationCache.size >= MAX_CACHE_ENTRIES) {
    const oldest = _classificationCache.keys().next().value;
    if (oldest !== undefined) {
      _classificationCache.delete(oldest);
    }
  }
  _classificationCache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

// ---------------------------------------------------------------------------
// Token usage enforcement
// ---------------------------------------------------------------------------

/**
 * Returns total tokens consumed by a user since midnight UTC today.
 * Used to enforce per-plan daily limits.
 */
async function getDailyTokenUsage(userId: string): Promise<number> {
  const sb = getSupabaseAdmin();
  const todayStart = new Date();
  todayStart.setUTCHours(0, 0, 0, 0);

  const { data } = await sb
    .from("ai_coaching_history")
    .select("tokens_input, tokens_output")
    .eq("user_id", userId)
    .gte("created_at", todayStart.toISOString());

  if (!data || data.length === 0) return 0;

  return data.reduce(
    (sum, r) => sum + (r.tokens_input ?? 0) + (r.tokens_output ?? 0),
    0,
  );
}

/**
 * Verifies that a user has not exceeded their plan's daily AI budget.
 * Throws {@link TokenLimitExceededError} if the limit is reached.
 *
 * @param userId - The Drift user UUID.
 * @param plan   - The user's current plan.
 */
async function enforceTokenLimit(userId: string, plan: PlanId): Promise<void> {
  const limit = DAILY_TOKEN_LIMITS[plan] ?? 0;
  if (limit === 0) {
    throw new TokenLimitExceededError(plan);
  }
  const used = await getDailyTokenUsage(userId);
  if (used >= limit) {
    throw new TokenLimitExceededError(plan);
  }
}

// ---------------------------------------------------------------------------
// API call wrapper with error handling
// ---------------------------------------------------------------------------

const MAX_API_RETRIES = 3;
const API_RETRY_BASE_MS = 1000;

/**
 * Wraps an Anthropic API call with retry logic for transient failures
 * (rate limits, overloaded errors, network issues).
 */
async function withRetry<T>(operation: string, fn: () => Promise<T>): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt < MAX_API_RETRIES; attempt++) {
    try {
      return await fn();
    } catch (err: unknown) {
      lastError = err;

      if (err instanceof Anthropic.APIError) {
        const retryable = err.status === 429 || err.status === 529 || err.status >= 500;

        if (!retryable || attempt === MAX_API_RETRIES - 1) {
          throw new AIServiceError(
            `AI ${operation} failed`,
            "AI_API_ERROR",
            err.status ?? 500,
            retryable,
          );
        }

        // Use Retry-After header if present, otherwise exponential backoff.
        const retryAfter = (err.headers as Record<string, string> | undefined)?.["retry-after"];
        const delayMs = retryAfter
          ? parseInt(retryAfter, 10) * 1000
          : API_RETRY_BASE_MS * Math.pow(2, attempt) + Math.random() * 500;

        await new Promise((r) => setTimeout(r, delayMs));
        continue;
      }

      throw err;
    }
  }

  throw lastError;
}

// ---------------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = `You are Drift Coach, an AI focus advisor embedded in Drift, a macOS browsing-focus tracker.

Your personality:
- Warm, concise, and data-driven.
- You reference specific domains and times from the session data.
- You never moralize or lecture; you give practical, actionable advice.
- You celebrate wins before addressing areas for improvement.

Coaching tone calibration:
- Drift score 0-15%: Congratulatory. Highlight what went right.
- Drift score 15-40%: Supportive with gentle, specific suggestions.
- Drift score 40%+: Direct but never judgmental. Focus on one key change.

Response format: You always respond with valid JSON matching the requested schema. No markdown fences, no preamble, no commentary outside the JSON.`;

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

function fmtMs(ms: number): string {
  const h = Math.floor(ms / 3_600_000);
  const m = Math.floor((ms % 3_600_000) / 60_000);
  const s = Math.floor((ms % 60_000) / 1000);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function pct(part: number, whole: number): number {
  if (whole === 0) return 0;
  return Math.round((part / whole) * 100);
}

// ---------------------------------------------------------------------------
// Session coaching (post-session AI analysis)
// ---------------------------------------------------------------------------

/**
 * Generates an AI coaching response for a completed browsing session.
 * Enforces per-plan token limits and persists the result.
 *
 * @param userId      - The Drift user UUID.
 * @param sessionData - Telemetry from the browsing session.
 * @param plan        - The user's current plan tier.
 * @returns Structured coaching response.
 */
export async function generateSessionCoaching(
  userId: string,
  sessionData: SessionData,
  plan: PlanId = "pro",
): Promise<CoachingResponse> {
  await enforceTokenLimit(userId, plan);

  const topSites = sessionData.topDomains
    .slice(0, 5)
    .map((d) => `${d.domain} (${fmtMs(d.timeMs)})`)
    .join(", ");

  const driftDetails = sessionData.driftPoints
    .slice(0, 5)
    .map((dp) => `- ${dp.reason} (${dp.trigger})`)
    .join("\n");

  const userMessage = `Analyze this browsing session and provide coaching.

SESSION DATA:
- Duration: ${fmtMs(sessionData.totalDurationMs)}
- Productive time: ${fmtMs(sessionData.productiveTimeMs)} (${pct(sessionData.productiveTimeMs, sessionData.totalDurationMs)}%)
- Distraction time: ${fmtMs(sessionData.distractionTimeMs)} (${pct(sessionData.distractionTimeMs, sessionData.totalDurationMs)}%)
- Drift score: ${sessionData.driftScore}%
- Drift points: ${sessionData.driftPointCount}
- Category switches: ${sessionData.categorySwitchCount}
- Longest productive streak: ${fmtMs(sessionData.longestProductiveStreakMs)}
- Longest distraction streak: ${fmtMs(sessionData.longestDistractionStreakMs)}
- Started on: ${sessionData.entryDomain}
- Ended on: ${sessionData.exitDomain}
- Top sites: ${topSites}
${driftDetails ? `\nDRIFT EVENTS:\n${driftDetails}` : ""}

Respond with ONLY valid JSON:
{
  "summary": "1-2 sentence session summary",
  "score": "great|good|okay|needs_work",
  "keyInsight": "the single most important observation",
  "actionItems": ["specific tip 1", "specific tip 2", "specific tip 3"],
  "encouragement": "brief positive closing",
  "pattern": "behavioral pattern if detected, null otherwise"
}`;

  const response = await withRetry("sessionCoaching", () =>
    claude().messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 512,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
    }),
  );

  const text =
    response.content[0].type === "text" ? response.content[0].text : "";

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new AIServiceError(
      "Failed to parse coaching response",
      "PARSE_ERROR",
      500,
      true,
    );
  }

  const validScores = ["great", "good", "okay", "needs_work"] as const;
  const rawScore = String(parsed.score ?? "okay");
  const score: CoachingResponse["score"] = validScores.includes(
    rawScore as (typeof validScores)[number],
  )
    ? (rawScore as CoachingResponse["score"])
    : "okay";

  const coaching: CoachingResponse = {
    summary: String(parsed.summary ?? "Session analyzed."),
    score,
    keyInsight: String(parsed.keyInsight ?? ""),
    actionItems: Array.isArray(parsed.actionItems)
      ? (parsed.actionItems as string[]).map(String).slice(0, 5)
      : [],
    encouragement: String(parsed.encouragement ?? "Keep going!"),
    pattern: parsed.pattern ? String(parsed.pattern) : undefined,
    tokensUsed: {
      input: response.usage.input_tokens,
      output: response.usage.output_tokens,
    },
  };

  // Persist coaching to database.
  const sb = getSupabaseAdmin();
  await sb.from("ai_coaching_history").insert({
    user_id: userId,
    session_data: sessionData,
    coaching_response: coaching,
    tokens_input: coaching.tokensUsed.input,
    tokens_output: coaching.tokensUsed.output,
    created_at: new Date().toISOString(),
  });

  return coaching;
}

// ---------------------------------------------------------------------------
// Streaming session coaching
// ---------------------------------------------------------------------------

/**
 * Streams coaching output token-by-token via an async generator.
 * The final event includes the complete parsed CoachingResponse.
 * Enforces plan-tier token limits before starting.
 *
 * @param userId      - The Drift user UUID.
 * @param sessionData - Telemetry from the browsing session.
 * @param plan        - The user's current plan tier.
 * @yields StreamingCoachEvent objects.
 */
export async function* streamSessionCoaching(
  userId: string,
  sessionData: SessionData,
  plan: PlanId = "pro",
): AsyncGenerator<StreamingCoachEvent> {
  await enforceTokenLimit(userId, plan);

  const topSites = sessionData.topDomains
    .slice(0, 5)
    .map((d) => `${d.domain} (${fmtMs(d.timeMs)})`)
    .join(", ");

  const driftDetails = sessionData.driftPoints
    .slice(0, 5)
    .map((dp) => `- ${dp.reason} (${dp.trigger})`)
    .join("\n");

  const userMessage = `Analyze this browsing session and provide coaching.

SESSION DATA:
- Duration: ${fmtMs(sessionData.totalDurationMs)}
- Productive: ${fmtMs(sessionData.productiveTimeMs)} (${pct(sessionData.productiveTimeMs, sessionData.totalDurationMs)}%)
- Distraction: ${fmtMs(sessionData.distractionTimeMs)} (${pct(sessionData.distractionTimeMs, sessionData.totalDurationMs)}%)
- Drift score: ${sessionData.driftScore}%
- Drift points: ${sessionData.driftPointCount}
- Top sites: ${topSites}
${driftDetails ? `\nDRIFT EVENTS:\n${driftDetails}` : ""}

Respond with ONLY valid JSON:
{
  "summary": "1-2 sentence session summary",
  "score": "great|good|okay|needs_work",
  "keyInsight": "the single most important observation",
  "actionItems": ["specific tip 1", "specific tip 2", "specific tip 3"],
  "encouragement": "brief positive closing",
  "pattern": "behavioral pattern if detected, null otherwise"
}`;

  let fullText = "";

  try {
    const stream = claude().messages.stream({
      model: "claude-sonnet-4-20250514",
      max_tokens: 512,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
    });

    for await (const event of stream) {
      if (
        event.type === "content_block_delta" &&
        event.delta.type === "text_delta"
      ) {
        fullText += event.delta.text;
        yield { type: "text_delta", delta: event.delta.text };
      }
    }

    const finalMessage = await stream.finalMessage();

    // Parse the accumulated text into a CoachingResponse.
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(fullText);
    } catch {
      yield { type: "error", error: "Failed to parse coaching response" };
      return;
    }

    const validScores = ["great", "good", "okay", "needs_work"] as const;
    const rawScore = String(parsed.score ?? "okay");
    const score: CoachingResponse["score"] = validScores.includes(
      rawScore as (typeof validScores)[number],
    )
      ? (rawScore as CoachingResponse["score"])
      : "okay";

    const coaching: CoachingResponse = {
      summary: String(parsed.summary ?? "Session analyzed."),
      score,
      keyInsight: String(parsed.keyInsight ?? ""),
      actionItems: Array.isArray(parsed.actionItems)
        ? (parsed.actionItems as string[]).map(String).slice(0, 5)
        : [],
      encouragement: String(parsed.encouragement ?? "Keep going!"),
      pattern: parsed.pattern ? String(parsed.pattern) : undefined,
      tokensUsed: {
        input: finalMessage.usage.input_tokens,
        output: finalMessage.usage.output_tokens,
      },
    };

    // Persist.
    const sb = getSupabaseAdmin();
    await sb.from("ai_coaching_history").insert({
      user_id: userId,
      session_data: sessionData,
      coaching_response: coaching,
      tokens_input: coaching.tokensUsed.input,
      tokens_output: coaching.tokensUsed.output,
      created_at: new Date().toISOString(),
    });

    yield { type: "complete", coaching };
  } catch (err: unknown) {
    const message =
      err instanceof Error ? err.message : "Unknown streaming error";
    yield { type: "error", error: message };
  }
}

// ---------------------------------------------------------------------------
// Weekly digest (AI-written email content)
// ---------------------------------------------------------------------------

/**
 * Generates AI-written content for the weekly email digest.
 *
 * @param userId - The Drift user UUID (for logging, not sent to Claude).
 * @param data   - Aggregated weekly telemetry.
 * @returns Subject line, HTML body, and plain-text body for the email.
 */
export async function generateWeeklyDigest(
  userId: string,
  data: WeeklyDigestData,
): Promise<{ subject: string; htmlBody: string; plainBody: string }> {
  const trend =
    data.previousWeekAvgDrift !== null
      ? data.averageDriftScore < data.previousWeekAvgDrift
        ? `DOWN ${Math.abs(data.averageDriftScore - data.previousWeekAvgDrift)}% from last week`
        : `UP ${data.averageDriftScore - data.previousWeekAvgDrift}% from last week`
      : "first week tracked";

  const userMessage = `Write a weekly email digest for a Drift user.

WEEK: ${data.weekStart} to ${data.weekEnd}
STATS:
- Sessions: ${data.sessionCount}
- Total browsing time: ${fmtMs(data.totalTimeMs)}
- Productive time: ${fmtMs(data.productiveTimeMs)}
- Distraction time: ${fmtMs(data.distractionTimeMs)}
- Average drift: ${data.averageDriftScore}% (${trend})
- Top sites: ${data.topDomains.slice(0, 5).map((d) => `${d.domain} (${fmtMs(d.timeMs)})`).join(", ")}
${data.bestDay ? `- Best day: ${data.bestDay.date} (${data.bestDay.driftScore}% drift)` : ""}
${data.worstDay ? `- Worst day: ${data.worstDay.date} (${data.worstDay.driftScore}% drift)` : ""}

Respond with ONLY valid JSON:
{
  "subject": "email subject (short, engaging, include an emoji)",
  "greeting": "personalized opening line",
  "highlights": ["highlight 1", "highlight 2", "highlight 3"],
  "tip": "one actionable tip for next week",
  "closing": "encouraging sign-off"
}`;

  const response = await withRetry("weeklyDigest", () =>
    claude().messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 512,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
    }),
  );

  const text =
    response.content[0].type === "text" ? response.content[0].text : "";

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new AIServiceError(
      "Failed to parse weekly digest response",
      "PARSE_ERROR",
      500,
      true,
    );
  }

  const subject = String(parsed.subject ?? "Your weekly Drift report");
  const greeting = String(parsed.greeting ?? "Here is your weekly summary.");
  const highlights = Array.isArray(parsed.highlights)
    ? (parsed.highlights as string[]).map(String)
    : [];
  const tip = String(parsed.tip ?? "Keep up the great work!");
  const closing = String(parsed.closing ?? "See you next week!");

  const driftColor =
    data.averageDriftScore <= 25
      ? "#1a8a3e"
      : data.averageDriftScore <= 50
        ? "#b8860b"
        : "#c43c3c";

  const htmlBody = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#1d1d1f;background:#fafafa">
  <div style="text-align:center;margin-bottom:24px">
    <h1 style="font-size:20px;font-weight:600;margin:0">drift</h1>
    <p style="color:#86868b;font-size:13px;margin:4px 0">${data.weekStart} &ndash; ${data.weekEnd}</p>
  </div>

  <p style="font-size:15px;line-height:1.5">${greeting}</p>

  <div style="background:#fff;border-radius:12px;padding:20px;margin:20px 0;border:1px solid #e5e5e7">
    <div style="display:flex;justify-content:space-between;text-align:center">
      <div><div style="font-size:24px;font-weight:600">${data.sessionCount}</div><div style="font-size:11px;color:#86868b">sessions</div></div>
      <div><div style="font-size:24px;font-weight:600">${fmtMs(data.totalTimeMs)}</div><div style="font-size:11px;color:#86868b">tracked</div></div>
      <div><div style="font-size:24px;font-weight:600;color:${driftColor}">${data.averageDriftScore}%</div><div style="font-size:11px;color:#86868b">drift</div></div>
    </div>
  </div>

  <ul style="padding-left:20px;line-height:1.8;font-size:14px">
    ${highlights.map((h) => `<li>${escapeHtml(h)}</li>`).join("\n    ")}
  </ul>

  <div style="background:#f0f7f1;border-radius:8px;padding:16px;margin:20px 0;font-size:14px">
    <strong>Tip for next week:</strong> ${escapeHtml(tip)}
  </div>

  <p style="font-size:14px;color:#86868b">${escapeHtml(closing)}</p>

  <hr style="border:none;border-top:1px solid #e5e5e7;margin:24px 0">
  <p style="font-size:11px;color:#86868b;text-align:center">
    <a href="{{unsubscribe_url}}" style="color:#86868b">Unsubscribe</a> &middot;
    <a href="https://getdrift.app" style="color:#86868b">Open Drift</a>
  </p>
</body>
</html>`;

  const plainBody = [greeting, "", ...highlights, "", `Tip: ${tip}`, "", closing].join("\n");

  return { subject, htmlBody, plainBody };
}

// ---------------------------------------------------------------------------
// Smart domain classification (AI-powered, with caching)
// ---------------------------------------------------------------------------

/**
 * Classifies a single domain as productive, neutral, or distraction.
 * Returns a cached result when available.
 *
 * @param domain    - The domain to classify (e.g. "github.com").
 * @param pageTitle - Optional page title for more context.
 * @param url       - Optional full URL for path-based classification.
 * @returns Classification with confidence and reasoning.
 */
export async function classifyDomainWithAI(
  domain: string,
  pageTitle?: string,
  url?: string,
): Promise<DomainClassification> {
  if (!domain) {
    throw new AIServiceError("Domain is required", "INVALID_INPUT", 400);
  }

  // Moderate user-influenced inputs.
  if (pageTitle) moderateContent(pageTitle);
  if (url) moderateContent(url);

  // Check cache first.
  const key = cacheKey(domain, pageTitle);
  const cached = getCached(key);
  if (cached) return cached;

  const userMessage = `Classify this website for a productivity tracker. Domain: ${domain}${pageTitle ? `, Title: "${pageTitle}"` : ""}${url ? `, URL: ${url}` : ""}

Reply with ONLY JSON: {"category":"productive|neutral|distraction","confidence":0.0-1.0,"reason":"brief explanation"}

Guidelines:
- productive: work tools, code, docs, learning, professional communication
- distraction: social media, entertainment, gaming, news aggregators
- neutral: search engines, utilities, shopping, reference sites
- Context matters: youtube.com/watch?v=coding_tutorial could be productive`;

  const response = await withRetry("classifyDomain", () =>
    claude().messages.create({
      model: "claude-haiku-3-5-20241022",
      max_tokens: 128,
      system: "You are a website classification engine. Respond only with valid JSON.",
      messages: [{ role: "user", content: userMessage }],
    }),
  );

  const text =
    response.content[0].type === "text" ? response.content[0].text : "";

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new AIServiceError(
      "Failed to parse classification response",
      "PARSE_ERROR",
      500,
      true,
    );
  }

  const validCategories = ["productive", "neutral", "distraction"] as const;
  const rawCategory = String(parsed.category ?? "neutral");
  const category: DomainClassification["category"] = validCategories.includes(
    rawCategory as (typeof validCategories)[number],
  )
    ? (rawCategory as DomainClassification["category"])
    : "neutral";

  const confidence = Math.max(0, Math.min(1, Number(parsed.confidence ?? 0.5)));

  const result: DomainClassification = {
    category,
    confidence,
    reason: String(parsed.reason ?? ""),
  };

  setCache(key, result);
  return result;
}

// ---------------------------------------------------------------------------
// Batch classify (up to 20 domains in one call, with caching)
// ---------------------------------------------------------------------------

/**
 * Classifies up to 20 domains in a single API call.
 * Returns cached results where available, only calls the API for misses.
 *
 * @param domains - Array of domain/title pairs to classify.
 * @returns Map of domain to classification result.
 */
export async function batchClassifyDomains(
  domains: { domain: string; title?: string }[],
): Promise<Map<string, { category: "productive" | "neutral" | "distraction"; confidence: number }>> {
  const results = new Map<
    string,
    { category: "productive" | "neutral" | "distraction"; confidence: number }
  >();

  // Separate cached from uncached.
  const uncached: { domain: string; title?: string }[] = [];
  for (const d of domains.slice(0, 20)) {
    if (d.title) moderateContent(d.title);

    const key = cacheKey(d.domain, d.title);
    const cached = getCached(key);
    if (cached) {
      results.set(d.domain, { category: cached.category, confidence: cached.confidence });
    } else {
      uncached.push(d);
    }
  }

  if (uncached.length === 0) return results;

  const domainList = uncached
    .map((d, i) => `${i + 1}. ${d.domain}${d.title ? ` ("${d.title}")` : ""}`)
    .join("\n");

  const userMessage = `Classify these websites for a productivity tracker:
${domainList}

Reply with ONLY a JSON array: [{"domain":"...","category":"productive|neutral|distraction","confidence":0.0-1.0}]`;

  const response = await withRetry("batchClassify", () =>
    claude().messages.create({
      model: "claude-haiku-3-5-20241022",
      max_tokens: 1024,
      system: "You are a website classification engine. Respond only with valid JSON.",
      messages: [{ role: "user", content: userMessage }],
    }),
  );

  const text =
    response.content[0].type === "text" ? response.content[0].text : "";

  let apiResults: { domain: string; category: string; confidence: number }[];
  try {
    apiResults = JSON.parse(text);
  } catch {
    throw new AIServiceError(
      "Failed to parse batch classification response",
      "PARSE_ERROR",
      500,
      true,
    );
  }

  if (!Array.isArray(apiResults)) {
    throw new AIServiceError(
      "Batch classification returned non-array",
      "PARSE_ERROR",
      500,
      true,
    );
  }

  const validCategories = new Set(["productive", "neutral", "distraction"]);

  for (const r of apiResults) {
    const cat = validCategories.has(r.category)
      ? (r.category as "productive" | "neutral" | "distraction")
      : "neutral";
    const conf = Math.max(0, Math.min(1, Number(r.confidence ?? 0.5)));

    results.set(r.domain, { category: cat, confidence: conf });

    // Cache individual results.
    const matchingInput = uncached.find((d) => d.domain === r.domain);
    setCache(cacheKey(r.domain, matchingInput?.title), {
      category: cat,
      confidence: conf,
      reason: "",
    });
  }

  return results;
}

// ---------------------------------------------------------------------------
// Cost tracking
// ---------------------------------------------------------------------------

/**
 * Returns aggregate AI usage stats for a user since a given date.
 * Used for billing dashboards and plan-limit warnings.
 *
 * @param userId - The Drift user UUID.
 * @param since  - Start date for the aggregation window.
 * @returns Token counts and estimated cost.
 */
export async function getAIUsageForUser(
  userId: string,
  since: Date,
): Promise<{ requests: number; inputTokens: number; outputTokens: number; estimatedCost: number }> {
  const sb = getSupabaseAdmin();
  const { data } = await sb
    .from("ai_coaching_history")
    .select("tokens_input, tokens_output")
    .eq("user_id", userId)
    .gte("created_at", since.toISOString());

  if (!data || data.length === 0) {
    return { requests: 0, inputTokens: 0, outputTokens: 0, estimatedCost: 0 };
  }

  const inputTokens = data.reduce((s, r) => s + (r.tokens_input ?? 0), 0);
  const outputTokens = data.reduce((s, r) => s + (r.tokens_output ?? 0), 0);

  // Claude Sonnet pricing: $3/MTok input, $15/MTok output.
  const estimatedCost = (inputTokens * 3 + outputTokens * 15) / 1_000_000;

  return { requests: data.length, inputTokens, outputTokens, estimatedCost };
}

// ---------------------------------------------------------------------------
// HTML escaping (prevent XSS in generated email content)
// ---------------------------------------------------------------------------

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
