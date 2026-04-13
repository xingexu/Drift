// ---------------------------------------------------------------------------
// Drift -- Stripe Billing Service
// ---------------------------------------------------------------------------
// Handles customer management, checkout sessions, subscription lifecycle,
// webhook processing with signature verification, and idempotent retries.
// ---------------------------------------------------------------------------

import Stripe from "stripe";
import crypto from "node:crypto";
import { getEnv } from "../config/env.js";
import { getSupabaseAdmin } from "../config/supabase.js";
import { PlanId, PLANS } from "../config/plans.js";

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/** Base class for all Stripe-related service errors. */
export class StripeServiceError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly retryable: boolean = false,
  ) {
    super(message);
    this.name = "StripeServiceError";
  }
}

/** Thrown when a webhook signature cannot be verified. */
export class WebhookVerificationError extends StripeServiceError {
  constructor() {
    super("Webhook signature verification failed", "WEBHOOK_SIGNATURE_INVALID", 400, false);
    this.name = "WebhookVerificationError";
  }
}

/** Thrown when a requested plan is invalid or unrecognized. */
export class InvalidPlanError extends StripeServiceError {
  constructor(plan: string) {
    super(`Invalid plan: ${plan}`, "INVALID_PLAN", 400, false);
    this.name = "InvalidPlanError";
  }
}

/** Thrown when no billing account exists for a user. */
export class NoBillingAccountError extends StripeServiceError {
  constructor() {
    super("No billing account found", "NO_BILLING_ACCOUNT", 404, false);
    this.name = "NoBillingAccountError";
  }
}

// ---------------------------------------------------------------------------
// Stripe client (singleton)
// ---------------------------------------------------------------------------

let _stripe: Stripe | null = null;

function stripe(): Stripe {
  if (!_stripe) {
    _stripe = new Stripe(getEnv().STRIPE_SECRET_KEY, {
      maxNetworkRetries: 2,
    });
  }
  return _stripe;
}

// ---------------------------------------------------------------------------
// Idempotency key generation
// ---------------------------------------------------------------------------

/**
 * Generates a deterministic idempotency key from constituent parts.
 * Stripe deduplicates POST requests sharing the same idempotency key
 * within a 24-hour window, preventing double-charges on retries.
 */
function idempotencyKey(...parts: string[]): string {
  return crypto.createHash("sha256").update(parts.join(":")).digest("hex").slice(0, 48);
}

// ---------------------------------------------------------------------------
// Retry wrapper
// ---------------------------------------------------------------------------

const MAX_RETRIES = 3;
const RETRY_BASE_MS = 500;

/**
 * Executes a Stripe API call with exponential-backoff retry for transient
 * errors (rate limits, network blips, 500s). Non-retryable errors such as
 * invalid parameters are thrown immediately.
 */
async function withRetry<T>(operation: string, fn: () => Promise<T>): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      return await fn();
    } catch (err: unknown) {
      lastError = err;

      if (err instanceof Stripe.errors.StripeError) {
        const retryable =
          err.type === "StripeConnectionError" ||
          err.type === "StripeAPIError" ||
          (err.type === "StripeRateLimitError") ||
          (err.statusCode !== undefined && err.statusCode >= 500);

        if (!retryable || attempt === MAX_RETRIES - 1) {
          throw new StripeServiceError(
            `Stripe ${operation} failed: ${err.message}`,
            err.code ?? "STRIPE_ERROR",
            err.statusCode ?? 500,
            retryable,
          );
        }

        const delayMs = RETRY_BASE_MS * Math.pow(2, attempt) + Math.random() * 200;
        await new Promise((r) => setTimeout(r, delayMs));
        continue;
      }

      // Non-Stripe error -- do not retry.
      throw err;
    }
  }

  throw lastError;
}

// ---------------------------------------------------------------------------
// Plan validation helpers
// ---------------------------------------------------------------------------

const BILLABLE_PLANS: PlanId[] = ["pro", "team"];

/**
 * Returns the Stripe Price ID for a given plan and interval.
 * Throws {@link InvalidPlanError} when the plan is not billable.
 */
function resolvePriceId(plan: PlanId, interval: "month" | "year"): string {
  if (!BILLABLE_PLANS.includes(plan)) {
    throw new InvalidPlanError(plan);
  }
  if (!PLANS[plan]) {
    throw new InvalidPlanError(plan);
  }

  const env = getEnv();
  const priceMap: Record<string, Record<string, string>> = {
    pro: { month: env.STRIPE_PRICE_PRO_MONTHLY, year: env.STRIPE_PRICE_PRO_YEARLY },
    team: { month: env.STRIPE_PRICE_TEAM_MONTHLY, year: env.STRIPE_PRICE_TEAM_YEARLY },
  };

  const priceId = priceMap[plan]?.[interval];
  if (!priceId) {
    throw new InvalidPlanError(`${plan}/${interval}`);
  }
  return priceId;
}

// ---------------------------------------------------------------------------
// Customer management
// ---------------------------------------------------------------------------

/**
 * Retrieves an existing Stripe customer ID for a Drift user, or creates
 * one if none exists. The mapping is persisted in user_profiles.
 *
 * @param userId - The Drift user UUID.
 * @param email  - The user's email address.
 * @returns The Stripe customer ID (cus_xxx).
 */
export async function getOrCreateCustomer(
  userId: string,
  email: string,
): Promise<string> {
  if (!userId || !email) {
    throw new StripeServiceError("userId and email are required", "INVALID_INPUT", 400);
  }

  const sb = getSupabaseAdmin();

  const { data: profile } = await sb
    .from("user_profiles")
    .select("stripe_customer_id")
    .eq("user_id", userId)
    .single();

  if (profile?.stripe_customer_id) {
    return profile.stripe_customer_id;
  }

  const customer = await withRetry("createCustomer", () =>
    stripe().customers.create(
      { email, metadata: { drift_user_id: userId } },
      { idempotencyKey: idempotencyKey("create-customer", userId) },
    ),
  );

  await sb.from("user_profiles").upsert({
    user_id: userId,
    stripe_customer_id: customer.id,
    updated_at: new Date().toISOString(),
  });

  return customer.id;
}

// ---------------------------------------------------------------------------
// Checkout session
// ---------------------------------------------------------------------------

/**
 * Creates a Stripe Checkout Session for a subscription purchase.
 * Validates the plan before calling Stripe.
 *
 * @param userId   - The Drift user UUID.
 * @param email    - The user's email address.
 * @param plan     - A billable plan ID ("pro" | "team").
 * @param interval - Billing interval ("month" | "year").
 * @returns The checkout session URL to redirect the user to.
 */
export async function createCheckoutSession(
  userId: string,
  email: string,
  plan: PlanId,
  interval: "month" | "year",
): Promise<string> {
  const priceId = resolvePriceId(plan, interval);
  const env = getEnv();
  const customerId = await getOrCreateCustomer(userId, email);

  const session = await withRetry("createCheckoutSession", () =>
    stripe().checkout.sessions.create(
      {
        customer: customerId,
        mode: "subscription",
        payment_method_types: ["card"],
        line_items: [{ price: priceId, quantity: 1 }],
        success_url: `${env.FRONTEND_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${env.FRONTEND_URL}/billing/cancel`,
        metadata: { drift_user_id: userId, plan },
        subscription_data: {
          metadata: { drift_user_id: userId, plan },
          trial_period_days: 14,
        },
        allow_promotion_codes: true,
      },
      { idempotencyKey: idempotencyKey("checkout", userId, plan, interval) },
    ),
  );

  if (!session.url) {
    throw new StripeServiceError("Checkout session created without URL", "NO_SESSION_URL", 500);
  }

  return session.url;
}

// ---------------------------------------------------------------------------
// Subscription upgrade / downgrade with proration
// ---------------------------------------------------------------------------

/**
 * Changes a user's active subscription to a different plan and/or interval.
 * Uses Stripe's proration to adjust billing immediately.
 *
 * @param userId      - The Drift user UUID.
 * @param newPlan     - Target plan ("pro" | "team").
 * @param newInterval - Target billing interval.
 * @returns The updated Stripe subscription object.
 */
export async function changeSubscription(
  userId: string,
  newPlan: PlanId,
  newInterval: "month" | "year",
): Promise<{ subscriptionId: string; status: string }> {
  const newPriceId = resolvePriceId(newPlan, newInterval);
  const sb = getSupabaseAdmin();

  const { data: profile } = await sb
    .from("user_profiles")
    .select("stripe_subscription_id")
    .eq("user_id", userId)
    .single();

  if (!profile?.stripe_subscription_id) {
    throw new NoBillingAccountError();
  }

  const subscription = await withRetry("getSubscription", () =>
    stripe().subscriptions.retrieve(profile.stripe_subscription_id),
  );

  if (subscription.items.data.length === 0) {
    throw new StripeServiceError("Subscription has no items", "NO_SUBSCRIPTION_ITEMS", 500);
  }

  const currentItem = subscription.items.data[0];

  const updated = await withRetry("updateSubscription", () =>
    stripe().subscriptions.update(
      profile.stripe_subscription_id,
      {
        items: [{ id: currentItem.id, price: newPriceId }],
        proration_behavior: "always_invoice",
        metadata: { drift_user_id: userId, plan: newPlan },
      },
      {
        idempotencyKey: idempotencyKey(
          "change-sub",
          userId,
          profile.stripe_subscription_id,
          newPriceId,
        ),
      },
    ),
  );

  await sb
    .from("user_profiles")
    .update({
      plan: newPlan,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId);

  return { subscriptionId: updated.id, status: updated.status };
}

// ---------------------------------------------------------------------------
// Customer portal (manage subscription)
// ---------------------------------------------------------------------------

/**
 * Creates a Stripe Billing Portal session so the user can manage their
 * subscription, update payment methods, or cancel.
 *
 * @param userId - The Drift user UUID.
 * @returns The portal session URL to redirect the user to.
 */
export async function createPortalSession(userId: string): Promise<string> {
  const sb = getSupabaseAdmin();
  const { data: profile } = await sb
    .from("user_profiles")
    .select("stripe_customer_id")
    .eq("user_id", userId)
    .single();

  if (!profile?.stripe_customer_id) {
    throw new NoBillingAccountError();
  }

  const session = await withRetry("createPortalSession", () =>
    stripe().billingPortal.sessions.create({
      customer: profile.stripe_customer_id,
      return_url: `${getEnv().FRONTEND_URL}/settings`,
    }),
  );

  return session.url;
}

// ---------------------------------------------------------------------------
// Webhook handler
// ---------------------------------------------------------------------------

/**
 * Processes an incoming Stripe webhook event.
 *
 * 1. Verifies the webhook signature using the signing secret.
 * 2. Routes the event to the appropriate handler.
 * 3. Updates the user_profiles table to reflect subscription state.
 *
 * Handles: checkout.session.completed, customer.subscription.created,
 * customer.subscription.updated, customer.subscription.deleted,
 * invoice.payment_failed, invoice.payment_succeeded.
 *
 * @param body      - The raw request body (Buffer) -- must not be parsed.
 * @param signature - The Stripe-Signature header value.
 */
export async function handleStripeWebhook(
  body: Buffer,
  signature: string,
): Promise<void> {
  if (!signature) {
    throw new WebhookVerificationError();
  }

  let event: Stripe.Event;
  try {
    event = stripe().webhooks.constructEvent(
      body,
      signature,
      getEnv().STRIPE_WEBHOOK_SECRET,
    );
  } catch {
    throw new WebhookVerificationError();
  }

  const sb = getSupabaseAdmin();

  switch (event.type) {
    // ----- Checkout completed -----
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const userId = session.metadata?.drift_user_id;
      const plan = session.metadata?.plan as PlanId | undefined;
      if (!userId) break;

      const resolvedPlan: PlanId = plan && PLANS[plan] ? plan : "pro";

      await sb.from("user_profiles").upsert({
        user_id: userId,
        plan: resolvedPlan,
        stripe_customer_id: session.customer as string,
        stripe_subscription_id: session.subscription as string,
        subscription_status: "active",
        trial_ends_at: null,
        updated_at: new Date().toISOString(),
      });
      break;
    }

    // ----- Subscription created -----
    case "customer.subscription.created": {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.drift_user_id;
      if (!userId) break;

      const plan: PlanId = (sub.metadata?.plan as PlanId) ?? "pro";
      const trialEnd = sub.trial_end
        ? new Date(sub.trial_end * 1000).toISOString()
        : null;

      await sb.from("user_profiles").upsert({
        user_id: userId,
        plan: PLANS[plan] ? plan : "pro",
        stripe_subscription_id: sub.id,
        subscription_status: sub.status,
        trial_ends_at: trialEnd,
        updated_at: new Date().toISOString(),
      });
      break;
    }

    // ----- Subscription updated (plan change, renewal, trial end, etc.) -----
    case "customer.subscription.updated": {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.drift_user_id;
      if (!userId) break;

      const status = sub.status;
      const plan = (sub.metadata?.plan ?? "pro") as PlanId;
      const cancelAt = sub.cancel_at
        ? new Date(sub.cancel_at * 1000).toISOString()
        : null;
      const trialEnd = sub.trial_end
        ? new Date(sub.trial_end * 1000).toISOString()
        : null;

      await sb
        .from("user_profiles")
        .update({
          plan: status === "active" || status === "trialing" ? plan : "free",
          subscription_status: status,
          cancel_at: cancelAt,
          trial_ends_at: trialEnd,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId);
      break;
    }

    // ----- Subscription canceled / deleted -----
    case "customer.subscription.deleted": {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.drift_user_id;
      if (!userId) break;

      await sb
        .from("user_profiles")
        .update({
          plan: "free",
          subscription_status: "canceled",
          stripe_subscription_id: null,
          cancel_at: null,
          trial_ends_at: null,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId);
      break;
    }

    // ----- Payment failed -----
    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      const customerId = invoice.customer as string;
      if (!customerId) break;

      const { data: profile } = await sb
        .from("user_profiles")
        .select("user_id")
        .eq("stripe_customer_id", customerId)
        .single();

      if (profile) {
        await sb
          .from("user_profiles")
          .update({
            subscription_status: "past_due",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", profile.user_id);
      }
      break;
    }

    // ----- Payment succeeded (reactivation after past_due) -----
    case "invoice.payment_succeeded": {
      const invoice = event.data.object as Stripe.Invoice;
      const customerId = invoice.customer as string;
      if (!customerId) break;

      const { data: profile } = await sb
        .from("user_profiles")
        .select("user_id, plan")
        .eq("stripe_customer_id", customerId)
        .single();

      if (profile && profile.plan !== "free") {
        await sb
          .from("user_profiles")
          .update({
            subscription_status: "active",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", profile.user_id);
      }
      break;
    }

    // Unhandled event types are silently ignored (Stripe sends many).
    default:
      break;
  }
}

// ---------------------------------------------------------------------------
// Subscription status query
// ---------------------------------------------------------------------------

/**
 * Returns the current subscription state for a user.
 *
 * @param userId - The Drift user UUID.
 * @returns Plan, status, trial end date, and cancellation date.
 */
export async function getSubscriptionStatus(userId: string): Promise<{
  plan: PlanId;
  status: string;
  trialEndsAt: string | null;
  cancelAt: string | null;
}> {
  const sb = getSupabaseAdmin();
  const { data: profile } = await sb
    .from("user_profiles")
    .select("plan, subscription_status, trial_ends_at, cancel_at")
    .eq("user_id", userId)
    .single();

  return {
    plan: (profile?.plan ?? "free") as PlanId,
    status: profile?.subscription_status ?? "none",
    trialEndsAt: profile?.trial_ends_at ?? null,
    cancelAt: profile?.cancel_at ?? null,
  };
}
