// ---------------------------------------------------------------------------
// Drift -- Rate Limiting Middleware
//
// - Per-endpoint rate limit tiers (auth = strict, reads = relaxed)
// - Standard X-RateLimit-* response headers on every request
// - Attempts Redis-backed storage; falls back to in-memory on failure so a
//   Redis outage never takes down the API
// ---------------------------------------------------------------------------

import { Request, Response, NextFunction } from "express";
import {
  RateLimiterMemory,
  RateLimiterRedis,
  RateLimiterAbstract,
  RateLimiterRes,
} from "rate-limiter-flexible";
import { AuthenticatedRequest } from "./auth.js";
import { getEnv } from "../config/env.js";

// ---------------------------------------------------------------------------
// Tier definitions
// ---------------------------------------------------------------------------

interface TierConfig {
  points: number;
  duration: number; // seconds
  blockDuration?: number; // seconds to block after exceeding
}

const TIERS: Record<string, TierConfig> = {
  // Auth endpoints -- strict to prevent brute-force
  auth: { points: 10, duration: 60 * 15, blockDuration: 60 * 15 }, // 10 per 15 min, block 15 min
  // General API -- comfortable for normal use
  api: { points: 120, duration: 60 }, // 120/min
  // AI coaching -- expensive, rate-limited per hour
  ai: { points: 10, duration: 3600 }, // 10/hr
  // Webhooks -- server-to-server, slightly relaxed
  webhook: { points: 60, duration: 60 }, // 60/min
  // Read-heavy endpoints -- more generous
  read: { points: 200, duration: 60 }, // 200/min
};

export type RateLimitTier = keyof typeof TIERS;

// ---------------------------------------------------------------------------
// Redis health check state
// ---------------------------------------------------------------------------

export interface RedisHealthResult {
  status: "ok" | "degraded" | "not_configured";
  latencyMs?: number;
  error?: string;
  mode: "redis" | "memory";
}

let _redisHealthy = false;
let _redisMode: "redis" | "memory" = "memory";

export function getRedisHealth(): RedisHealthResult {
  const env = getEnv();
  if (!env.REDIS_URL) {
    return { status: "not_configured", mode: "memory" };
  }
  return {
    status: _redisHealthy ? "ok" : "degraded",
    mode: _redisMode,
    ...(!_redisHealthy && { error: "Redis unreachable, using in-memory fallback" }),
  };
}

// ---------------------------------------------------------------------------
// Limiter factory -- tries Redis, falls back to memory
// ---------------------------------------------------------------------------

let _redisClient: import("ioredis").default | null = null;

async function getRedisClient(): Promise<import("ioredis").default | null> {
  const env = getEnv();
  if (!env.REDIS_URL) return null;

  if (_redisClient) return _redisClient;

  try {
    const { default: Redis } = await import("ioredis");
    const client = new Redis(env.REDIS_URL, {
      enableOfflineQueue: false,
      maxRetriesPerRequest: 1,
      connectTimeout: 3000,
      lazyConnect: true,
    });

    await client.connect();

    client.on("error", (err) => {
      console.warn("[RateLimit] Redis error:", err.message);
      _redisHealthy = false;
      _redisMode = "memory";
    });

    client.on("ready", () => {
      _redisHealthy = true;
      _redisMode = "redis";
    });

    _redisClient = client;
    _redisHealthy = true;
    _redisMode = "redis";
    console.log("[RateLimit] Connected to Redis");
    return client;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.warn(`[RateLimit] Redis unavailable (${msg}), using in-memory fallback`);
    _redisHealthy = false;
    _redisMode = "memory";
    return null;
  }
}

// Cache limiters so we create at most one per tier
const limiters = new Map<string, RateLimiterAbstract>();

async function getLimiter(tier: string): Promise<RateLimiterAbstract> {
  const existing = limiters.get(tier);
  if (existing) return existing;

  const config = TIERS[tier] ?? TIERS.api;
  const keyPrefix = `drift-rl-${tier}`;

  const memoryFallback = new RateLimiterMemory({
    points: config.points,
    duration: config.duration,
    blockDuration: config.blockDuration,
    keyPrefix,
  });

  const redis = await getRedisClient();

  if (redis) {
    try {
      const redisLimiter = new RateLimiterRedis({
        storeClient: redis,
        points: config.points,
        duration: config.duration,
        blockDuration: config.blockDuration,
        keyPrefix,
        // Fall back to in-memory if Redis fails mid-request
        insuranceLimiter: memoryFallback,
      });
      limiters.set(tier, redisLimiter);
      return redisLimiter;
    } catch {
      console.warn(`[RateLimit] Failed to create Redis limiter for "${tier}", using memory`);
    }
  }

  limiters.set(tier, memoryFallback);
  return memoryFallback;
}

// ---------------------------------------------------------------------------
// X-RateLimit-* headers
// ---------------------------------------------------------------------------

function setRateLimitHeaders(
  res: Response,
  tierConfig: TierConfig,
  result: RateLimiterRes,
): void {
  res.setHeader("X-RateLimit-Limit", tierConfig.points);
  res.setHeader("X-RateLimit-Remaining", Math.max(0, result.remainingPoints));
  res.setHeader(
    "X-RateLimit-Reset",
    Math.ceil(Date.now() / 1000 + result.msBeforeNext / 1000),
  );
}

// ---------------------------------------------------------------------------
// Middleware factory
// ---------------------------------------------------------------------------

export function rateLimit(tier: RateLimitTier = "api") {
  const tierConfig = TIERS[tier] ?? TIERS.api;

  return async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    // Key: authenticated userId > IP > fallback
    const key =
      (req as AuthenticatedRequest).userId ??
      req.ip ??
      req.socket.remoteAddress ??
      "anonymous";

    try {
      const limiter = await getLimiter(tier);
      const result = await limiter.consume(key);
      setRateLimitHeaders(res, tierConfig, result);
      next();
    } catch (err: unknown) {
      // RateLimiterRes is thrown when the limit is exceeded
      if (err instanceof Error) {
        // Unexpected error -- let it through so the request is not blocked
        console.error("[RateLimit] Unexpected error:", err.message);
        next();
        return;
      }

      const rlRes = err as RateLimiterRes;
      const retryAfter = Math.ceil(rlRes.msBeforeNext / 1000);

      res.setHeader("Retry-After", retryAfter);
      res.setHeader("X-RateLimit-Limit", tierConfig.points);
      res.setHeader("X-RateLimit-Remaining", 0);
      res.setHeader(
        "X-RateLimit-Reset",
        Math.ceil(Date.now() / 1000 + rlRes.msBeforeNext / 1000),
      );

      res.status(429).json({
        error: "Too many requests",
        code: "RATE_LIMITED",
        retryAfter,
      });
    }
  };
}
