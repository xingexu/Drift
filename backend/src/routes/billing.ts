// ---------------------------------------------------------------------------
// Drift -- Billing Routes (Stripe checkout, portal, webhooks)
// ---------------------------------------------------------------------------

import { Router, Request, Response } from "express";
import { z } from "zod";
import { requireAuth, AuthenticatedRequest } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rateLimit.js";
import { RateLimiterMemory } from "rate-limiter-flexible";
import {
  createCheckoutSession,
  createPortalSession,
  getSubscriptionStatus,
  handleStripeWebhook,
} from "../services/stripe.js";
import { PlanId, PLANS } from "../config/plans.js";
import crypto from "node:crypto";

const router = Router();

// ---------------------------------------------------------------------------
// Shared types & helpers
// ---------------------------------------------------------------------------

interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

function apiError(code: string, message: string, details?: unknown): ApiErrorResponse {
  return { error: { code, message, ...(details !== undefined && { details }) } };
}

function asyncHandler(
  fn: (req: Request, res: Response) => Promise<void>,
): (req: Request, res: Response) => void {
  return (req, res) => {
    fn(req, res).catch((err: unknown) => {
      const message = err instanceof Error ? err.message : "Unknown error";
      console.error(`[Billing] Unhandled error on ${req.method} ${req.path}:`, message);
      res.status(500).json(apiError("INTERNAL_ERROR", "An unexpected error occurred"));
    });
  };
}

function validateBody<T extends z.ZodTypeAny>(
  schema: T,
  req: Request,
  res: Response,
): z.infer<T> | null {
  const result = schema.safeParse(req.body);
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      field: i.path.join("."),
      message: i.message,
    }));
    res.status(400).json(apiError("VALIDATION_ERROR", details[0].message, details));
    return null;
  }
  return result.data;
}

function computeETag(payload: unknown): string {
  const hash = crypto.createHash("md5").update(JSON.stringify(payload)).digest("hex");
  return `W/"${hash}"`;
}

function handleConditionalGet(
  req: Request,
  res: Response,
  payload: unknown,
  maxAge: number = 0,
): boolean {
  const etag = computeETag(payload);
  res.setHeader("ETag", etag);
  res.setHeader("Cache-Control", `private, max-age=${maxAge}`);
  if (req.headers["if-none-match"] === etag) {
    res.status(304).end();
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Stricter rate limiter for billing actions (prevent abuse)
// ---------------------------------------------------------------------------

const billingLimiter = new RateLimiterMemory({
  points: 10,
  duration: 60,
  keyPrefix: "billing",
});

function billingRateLimit() {
  return async (req: Request, res: Response, next: () => void): Promise<void> => {
    const authReq = req as AuthenticatedRequest;
    const key = authReq.userId ?? req.ip ?? "anonymous";
    try {
      await billingLimiter.consume(key);
      next();
    } catch {
      res.status(429).json(apiError("RATE_LIMITED", "Too many billing requests. Please try again shortly."));
    }
  };
}

// ---------------------------------------------------------------------------
// Validation schemas
// ---------------------------------------------------------------------------

const checkoutSchema = z.object({
  plan: z.enum(["pro", "team"], {
    errorMap: () => ({ message: "Plan must be 'pro' or 'team'" }),
  }),
  interval: z.enum(["month", "year"], {
    errorMap: () => ({ message: "Interval must be 'month' or 'year'" }),
  }),
  /** Optional idempotency key to prevent duplicate checkout sessions. */
  idempotencyKey: z.string().uuid().optional(),
});

// ---------------------------------------------------------------------------
// GET /api/billing/plans -- List available plans
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/billing/plans
 * @desc    Return the list of available subscription plans and their pricing.
 *          Public -- no auth required. Cacheable for 5 minutes.
 * @access  Public
 * @returns { plans: Plan[] }
 */
router.get(
  "/plans",
  (_req: Request, res: Response) => {
    const plans = Object.values(PLANS).map((p) => ({
      id: p.id,
      name: p.name,
      priceMonthly: p.priceMonthly,
      priceYearly: p.priceYearly,
      features: p.features,
    }));

    const payload = { plans };

    // Plans change infrequently; cache aggressively
    const etag = computeETag(payload);
    res.setHeader("ETag", etag);
    res.setHeader("Cache-Control", "public, max-age=300");

    if (_req.headers["if-none-match"] === etag) {
      res.status(304).end();
      return;
    }

    res.json(payload);
  },
);

// ---------------------------------------------------------------------------
// GET /api/billing/status -- Get current subscription
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/billing/status
 * @desc    Return the authenticated user's current subscription status.
 * @access  Private (Bearer token)
 * @returns SubscriptionStatus
 */
router.get(
  "/status",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const status = await getSubscriptionStatus(authReq.userId);

    if (handleConditionalGet(req, res, status, 30)) return;
    res.json(status);
  }),
);

// ---------------------------------------------------------------------------
// POST /api/billing/checkout -- Create Stripe checkout session
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/billing/checkout
 * @desc    Create a Stripe Checkout session and return the redirect URL.
 * @access  Private (Bearer token, billing-rate-limited)
 * @body    { plan: "pro" | "team", interval: "month" | "year", idempotencyKey?: string }
 * @returns { url: string }
 */
router.post(
  "/checkout",
  requireAuth,
  billingRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(checkoutSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;

    const url = await createCheckoutSession(
      authReq.userId,
      authReq.userEmail,
      body.plan as PlanId,
      body.interval,
    );

    res.json({ url });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/billing/portal -- Open Stripe customer portal
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/billing/portal
 * @desc    Create a Stripe Customer Portal session and return the redirect URL.
 * @access  Private (Bearer token, billing-rate-limited)
 * @returns { url: string }
 */
router.post(
  "/portal",
  requireAuth,
  billingRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const url = await createPortalSession(authReq.userId);
    res.json({ url });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/webhooks/stripe -- Stripe webhook
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/webhooks/stripe
 * @desc    Receive Stripe webhook events. The body is the raw Buffer signed by
 *          Stripe, verified via `stripe-signature` header.
 * @access  Public (signature-verified)
 * @returns { received: true }
 */
router.post(
  "/webhooks/stripe",
  rateLimit("webhook"),
  asyncHandler(async (req: Request, res: Response) => {
    const sig = req.headers["stripe-signature"];
    if (!sig || typeof sig !== "string") {
      res.status(400).json(apiError("MISSING_SIGNATURE", "Missing stripe-signature header"));
      return;
    }

    try {
      await handleStripeWebhook(req.body as Buffer, sig);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Webhook processing failed";
      console.error("[Stripe Webhook Error]", message);
      // Return 400 so Stripe knows to retry
      res.status(400).json(apiError("WEBHOOK_ERROR", "Webhook verification or processing failed"));
      return;
    }

    res.json({ received: true });
  }),
);

export default router;
