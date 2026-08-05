/**
 * Connection pool factory. One pool per process — never create a pool
 * per request, and never use a single long-lived connection (it kills
 * both throughput and resilience to network blips).
 *
 * Defaults here are deliberately conservative for a typical web
 * backend talking to a single MySQL instance; override via env vars
 * for your actual load profile (see .env.example).
 */
import mysql, { Pool, PoolOptions } from "mysql2/promise";

export interface DbConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  connectionLimit?: number;
  ssl?: boolean;
}

export function loadConfigFromEnv(): DbConfig {
  const required = ["DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME"];
  const missing = required.filter((k) => !process.env[k]);
  if (missing.length) {
    throw new Error(
      `Missing required env vars: ${missing.join(", ")}. Copy .env.example to .env and fill them in.`
    );
  }
  return {
    host: process.env.DB_HOST!,
    port: Number(process.env.DB_PORT),
    user: process.env.DB_USER!,
    password: process.env.DB_PASSWORD!,
    database: process.env.DB_NAME!,
    connectionLimit: process.env.DB_POOL_SIZE ? Number(process.env.DB_POOL_SIZE) : 10,
    ssl: process.env.DB_SSL === "true",
  };
}

let pool: Pool | null = null;

export function getPool(config?: DbConfig): Pool {
  if (pool) return pool;

  const cfg = config ?? loadConfigFromEnv();

  const options: PoolOptions = {
    host: cfg.host,
    port: cfg.port,
    user: cfg.user,
    password: cfg.password,
    database: cfg.database,

    // --- Throughput & robustness -----------------------------------
    waitForConnections: true, // queue requests instead of throwing when the pool is exhausted
    connectionLimit: cfg.connectionLimit ?? 10, // tune to (CPU cores * 2..4) as a starting point, then measure
    maxIdle: cfg.connectionLimit ?? 10, // keep warm connections instead of reopening TCP+TLS each time
    idleTimeout: 60_000, // close connections idle longer than this (ms) — frees resources under low traffic
    queueLimit: 0, // 0 = unbounded queue; pair with a request-level timeout upstream (see withTimeout below)
    enableKeepAlive: true,
    keepAliveInitialDelay: 10_000,

    // --- Correctness -------------------------------------------------
    timezone: "Z", // always talk to MySQL in UTC; convert at the edges, never in the middle of the stack
    dateStrings: false,
    decimalNumbers: false, // keep DECIMAL as string to avoid float rounding surprises on money-like values
    supportBigNumbers: true,
    charset: "utf8mb4",

    // --- Security ------------------------------------------------------
    ssl: cfg.ssl ? { rejectUnauthorized: true } : undefined,
    multipleStatements: false, // never enable this — it's a SQL-injection amplifier
  };

  pool = mysql.createPool(options);
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
