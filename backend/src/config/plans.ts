// ---------------------------------------------------------------------------
// Drift -- Subscription Plans & Feature Gates
//
// All plan definitions are validated by Zod at import time so typos in
// feature flags are caught immediately rather than at runtime.
// ---------------------------------------------------------------------------

import { z } from "zod";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export const PLAN_IDS = ["free", "pro", "team"] as const;
export type PlanId = (typeof PLAN_IDS)[number];

/**
 * Zod guard -- useful for validating user input / DB values.
 */
export const planIdSchema = z.enum(PLAN_IDS);

export function isPlanId(value: unknown): value is PlanId {
  return planIdSchema.safeParse(value).success;
}

// ---------------------------------------------------------------------------
// Feature schema -- every boolean, number and array field is explicitly
// typed so a bad config is caught before the server starts.
// ---------------------------------------------------------------------------

const planFeaturesSchema = z.object({
  maxSessions: z.number().int().min(0),
  maxHistoryDays: z.number().int().min(1),
  aiCoachingPerDay: z.number().int().min(0),
  aiWeeklyDigest: z.boolean(),
  smartClassification: z.boolean(),
  customDomainRules: z.number().int().min(0),
  exportFormats: z.array(z.string()).min(1),
  teamDashboard: z.boolean(),
  maxTeamMembers: z.number().int().min(0),
  apiAccess: z.boolean(),
  prioritySupport: z.boolean(),
  realtimeAlerts: z.boolean(),
  goalTracking: z.boolean(),
  focusMode: z.boolean(),
  studyMode: z.boolean(),
});

export type PlanFeatures = z.infer<typeof planFeaturesSchema>;

const planConfigSchema = z.object({
  id: planIdSchema,
  name: z.string().min(1),
  priceMonthly: z.number().int().min(0), // cents
  priceYearly: z.number().int().min(0),  // cents
  features: planFeaturesSchema,
});

export type PlanConfig = z.infer<typeof planConfigSchema>;

// ---------------------------------------------------------------------------
// Plan definitions -- validated at module load time
// ---------------------------------------------------------------------------

const _plans: Record<PlanId, PlanConfig> = {
  free: {
    id: "free",
    name: "Free",
    priceMonthly: 0,
    priceYearly: 0,
    features: {
      maxSessions: 10,
      maxHistoryDays: 7,
      aiCoachingPerDay: 0,
      aiWeeklyDigest: false,
      smartClassification: false,
      customDomainRules: 5,
      exportFormats: ["json"],
      teamDashboard: false,
      maxTeamMembers: 0,
      apiAccess: false,
      prioritySupport: false,
      realtimeAlerts: true,
      goalTracking: false,
      focusMode: false,
      studyMode: false,
    },
  },
  pro: {
    id: "pro",
    name: "Pro",
    priceMonthly: 900,   // $9/mo
    priceYearly: 7200,   // $72/yr ($6/mo)
    features: {
      maxSessions: 0,    // unlimited
      maxHistoryDays: 365,
      aiCoachingPerDay: 10,
      aiWeeklyDigest: true,
      smartClassification: true,
      customDomainRules: 100,
      exportFormats: ["json", "csv", "pdf"],
      teamDashboard: false,
      maxTeamMembers: 0,
      apiAccess: true,
      prioritySupport: false,
      realtimeAlerts: true,
      goalTracking: true,
      focusMode: true,
      studyMode: true,
    },
  },
  team: {
    id: "team",
    name: "Team",
    priceMonthly: 1900,  // $19/user/mo
    priceYearly: 15600,  // $156/user/yr ($13/user/mo)
    features: {
      maxSessions: 0,
      maxHistoryDays: 365,
      aiCoachingPerDay: 25,
      aiWeeklyDigest: true,
      smartClassification: true,
      customDomainRules: 500,
      exportFormats: ["json", "csv", "pdf"],
      teamDashboard: true,
      maxTeamMembers: 50,
      apiAccess: true,
      prioritySupport: true,
      realtimeAlerts: true,
      goalTracking: true,
      focusMode: true,
      studyMode: true,
    },
  },
};

// Validate every plan at import time -- a malformed config crashes the
// process immediately rather than causing subtle runtime errors.
for (const [id, config] of Object.entries(_plans)) {
  const result = planConfigSchema.safeParse(config);
  if (!result.success) {
    const issues = result.error.issues
      .map((i) => `  - ${i.path.join(".")}: ${i.message}`)
      .join("\n");
    throw new Error(
      `[FATAL] Plan "${id}" failed validation:\n${issues}`,
    );
  }
}

/**
 * Immutable plan lookup table. Validated at startup.
 */
export const PLANS: Readonly<Record<PlanId, Readonly<PlanConfig>>> =
  Object.freeze(_plans);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

export function getPlan(planId: PlanId): PlanConfig {
  return PLANS[planId] ?? PLANS.free;
}

/**
 * Safe plan lookup from an untrusted string (e.g. DB column).
 * Returns the plan config or `PLANS.free` if the value is invalid.
 */
export function getPlanSafe(raw: unknown): PlanConfig {
  const parsed = planIdSchema.safeParse(raw);
  return parsed.success ? PLANS[parsed.data] : PLANS.free;
}

export function canUseFeature(
  planId: PlanId,
  feature: keyof PlanFeatures,
): boolean {
  const plan = getPlan(planId);
  const value = plan.features[feature];
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value > 0;
  return true;
}

/**
 * Ordered plan hierarchy for comparison. Higher index = more permissive.
 */
const PLAN_RANK: Record<PlanId, number> = { free: 0, pro: 1, team: 2 };

export function planAtLeast(current: PlanId, minimum: PlanId): boolean {
  return PLAN_RANK[current] >= PLAN_RANK[minimum];
}
