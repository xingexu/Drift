// ---------------------------------------------------------------------------
// Drift Backend -- Environment Configuration
// Validates ALL env vars on startup using Zod. Fails fast with actionable
// error messages so misconfigurations are caught before the server accepts
// traffic.
// ---------------------------------------------------------------------------

import { z } from "zod";

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------

const envSchema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3001),
  NODE_ENV: z
    .enum(["development", "production", "test"])
    .default("development"),
  API_SECRET: z
    .string()
    .min(32, "API_SECRET must be at least 32 characters"),

  // -- Supabase ---------------------------------------------------------------
  SUPABASE_URL: z.string().url("SUPABASE_URL must be a valid URL"),
  SUPABASE_SERVICE_ROLE_KEY: z
    .string()
    .min(1, "SUPABASE_SERVICE_ROLE_KEY is required"),
  SUPABASE_ANON_KEY: z.string().min(1, "SUPABASE_ANON_KEY is required"),
  SUPABASE_JWT_SECRET: z
    .string()
    .min(32, "SUPABASE_JWT_SECRET must be at least 32 characters")
    .optional(),

  // -- Stripe -----------------------------------------------------------------
  STRIPE_SECRET_KEY: z
    .string()
    .startsWith("sk_", "STRIPE_SECRET_KEY must start with sk_"),
  STRIPE_WEBHOOK_SECRET: z
    .string()
    .startsWith("whsec_", "STRIPE_WEBHOOK_SECRET must start with whsec_"),
  STRIPE_PRICE_PRO_MONTHLY: z
    .string()
    .min(1, "STRIPE_PRICE_PRO_MONTHLY is required"),
  STRIPE_PRICE_PRO_YEARLY: z
    .string()
    .min(1, "STRIPE_PRICE_PRO_YEARLY is required"),
  STRIPE_PRICE_TEAM_MONTHLY: z
    .string()
    .min(1, "STRIPE_PRICE_TEAM_MONTHLY is required"),
  STRIPE_PRICE_TEAM_YEARLY: z
    .string()
    .min(1, "STRIPE_PRICE_TEAM_YEARLY is required"),

  // -- Anthropic --------------------------------------------------------------
  ANTHROPIC_API_KEY: z
    .string()
    .min(10, "ANTHROPIC_API_KEY looks too short"),

  // -- Email (optional in dev, required in prod) ------------------------------
  SMTP_HOST: z.string().default("smtp.resend.com"),
  SMTP_PORT: z.coerce.number().int().min(1).max(65535).default(587),
  SMTP_USER: z.string().default("resend"),
  SMTP_PASS: z.string().default("re_dev_placeholder"),
  EMAIL_FROM: z.string().default("Drift <hello@getdrift.app>"),

  // -- Redis (optional -- rate limiter falls back to in-memory) ---------------
  REDIS_URL: z.string().url("REDIS_URL must be a valid URL").optional(),

  // -- Frontend / App ---------------------------------------------------------
  FRONTEND_URL: z.string().url().default("https://getdrift.app"),
  APP_SCHEME: z.string().default("drift"),

  // -- CORS -------------------------------------------------------------------
  CORS_ORIGINS: z
    .string()
    .optional()
    .describe("Comma-separated list of extra allowed CORS origins"),
}).superRefine((env, ctx) => {
  if (env.NODE_ENV !== "production") return;

  const rejectPlaceholder = (key: keyof typeof env, value: string) => {
    if (/placeholder|your-|_test_/i.test(value)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: [key],
        message: `${key} must not use a development or placeholder value in production`,
      });
    }
  };

  rejectPlaceholder("API_SECRET", env.API_SECRET);
  rejectPlaceholder("SUPABASE_SERVICE_ROLE_KEY", env.SUPABASE_SERVICE_ROLE_KEY);
  rejectPlaceholder("SUPABASE_ANON_KEY", env.SUPABASE_ANON_KEY);
  rejectPlaceholder("STRIPE_SECRET_KEY", env.STRIPE_SECRET_KEY);
  rejectPlaceholder("STRIPE_WEBHOOK_SECRET", env.STRIPE_WEBHOOK_SECRET);
  rejectPlaceholder("ANTHROPIC_API_KEY", env.ANTHROPIC_API_KEY);
  rejectPlaceholder("SMTP_PASS", env.SMTP_PASS);

  if (!env.FRONTEND_URL.startsWith("https://")) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["FRONTEND_URL"],
      message: "FRONTEND_URL must use HTTPS in production",
    });
  }
});

export type Env = z.infer<typeof envSchema>;

// ---------------------------------------------------------------------------
// Singleton -- parsed once, cached forever
// ---------------------------------------------------------------------------

let _env: Env | null = null;

/**
 * Parse and validate environment variables. On the first call the schema is
 * evaluated and any violations cause the process to exit with a clear
 * diagnostic so operators never run a misconfigured server.
 */
export function getEnv(): Env {
  if (!_env) {
    const result = envSchema.safeParse(process.env);

    if (!result.success) {
      const issues = result.error.issues
        .map(
          (i) =>
            `  - ${i.path.join(".")}: ${i.message}`,
        )
        .join("\n");

      console.error(
        "\n[FATAL] Environment validation failed:\n" +
          issues +
          "\n\nFix the above variables and restart.\n",
      );

      process.exit(1);
    }

    _env = result.data;
  }
  return _env;
}

/**
 * Convenience helpers.
 */
export function isDev(): boolean {
  return getEnv().NODE_ENV === "development";
}

export function isProd(): boolean {
  return getEnv().NODE_ENV === "production";
}

export function isTest(): boolean {
  return getEnv().NODE_ENV === "test";
}
