/**
 * Reference implementation: how a frontend should actually reach this
 * database — through a small backend like this one, never directly.
 * A browser can never hold DB credentials or run SQL; a JWT-protected
 * REST API (or GraphQL, or tRPC — the pattern is the same) is the
 * boundary. See ../../docs/CONNECTING.md for the full explanation.
 *
 * This is a reference, not a finished product: add input validation
 * (zod/joi), structured logging, request tracing, and a real refresh-
 * token rotation policy before shipping this to production.
 */
import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "node:crypto";
import type { PoolConnection } from "mysql2/promise";
import {
  getPool,
  withUserContext,
  findUserByEmail,
  createUser,
  createSession,
  findActiveSessionByTokenHash,
  revokeSession,
  recordFailedLogin,
  recordSuccessfulLogin,
  isAccountLocked,
} from "mysql-database-client";

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v) throw new Error(`Missing required env var: ${key}. Copy .env.example to .env.`);
  return v;
}

const JWT_SECRET = requireEnv("JWT_SECRET");
const JWT_TTL = process.env.JWT_TTL ?? "15m";
const REFRESH_TTL_DAYS = Number(process.env.REFRESH_TTL_DAYS ?? 30);
const PORT = Number(process.env.PORT ?? 4000);
const CORS_ORIGIN = process.env.CORS_ORIGIN ?? "http://localhost:5173";

/**
 * Express 4 does NOT forward rejected promises from async handlers to
 * the error middleware automatically — an unhandled rejection there
 * crashes the whole Node process (Node 15+ default: unhandled
 * rejections are fatal). Every async route below is wrapped in this so
 * a single failing request becomes a 500 response instead of an
 * outage for every other in-flight request.
 */
function ah(
  fn: (req: express.Request, res: express.Response, next: express.NextFunction) => Promise<any>
) {
  return (req: express.Request, res: express.Response, next: express.NextFunction) => {
    fn(req, res, next).catch(next);
  };
}

const pool = getPool();
const app = express();

app.disable("x-powered-by");
app.set("trust proxy", 1); // needed for req.ip to be correct behind a reverse proxy/load balancer
app.use(helmet());
app.use(cors({ origin: CORS_ORIGIN, credentials: true }));
app.use(express.json({ limit: "32kb" }));

// App-layer rate limiting on auth endpoints, complementing (not
// replacing) the DB-layer lockout in register_failed_login().
const authLimiter = rateLimit({ windowMs: 60_000, limit: 10, standardHeaders: true });

function hashToken(raw: string): string {
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function signAccessToken(userId: string): string {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: JWT_TTL as any });
}

app.get("/health", ah(async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok" });
  } catch {
    res.status(503).json({ status: "unavailable" });
  }
}));

app.post("/auth/register", authLimiter, ah(async (req, res) => {
  const { email, password, username, fullName } = req.body ?? {};
  if (typeof email !== "string" || typeof password !== "string" || password.length < 8) {
    return res.status(400).json({ error: "email and a password of at least 8 characters are required" });
  }

  const existing = await findUserByEmail(pool, email);
  if (existing) return res.status(409).json({ error: "email already registered" });

  const passwordHash = await bcrypt.hash(password, 12);
  const userId = await createUser(pool, { email, username, passwordHash, fullName });

  res.status(201).json({ id: userId, email });
}));

app.post("/auth/login", authLimiter, ah(async (req, res) => {
  const { email, password } = req.body ?? {};
  if (typeof email !== "string" || typeof password !== "string") {
    return res.status(400).json({ error: "email and password are required" });
  }

  const user = await findUserByEmail(pool, email);
  // Deliberately identical error for "no such user" and "wrong
  // password" — don't leak which one it was.
  const invalid = () => res.status(401).json({ error: "invalid email or password" });
  if (!user) return invalid();

  if (await isAccountLocked(pool, user.id)) {
    return res.status(423).json({ error: "account temporarily locked — try again later" });
  }

  const passwordOk = await bcrypt.compare(password, user.password_hash);
  if (!passwordOk) {
    await recordFailedLogin(pool, user.id);
    return invalid();
  }

  await recordSuccessfulLogin(pool, user.id);

  const refreshTokenRaw = crypto.randomBytes(48).toString("hex");
  const expiresAt = new Date(Date.now() + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);

  // Goes through v_my_sessions (WITH CASCADED CHECK OPTION), scoped to
  // this user — see client/src/queries.ts and
  // migrations/009_security_hardening.sql for why app_rw has no direct
  // grant on the base `sessions` table.
  await withUserContext(pool, user.id, (conn: PoolConnection) =>
    createSession(conn, {
      userId: user.id,
      refreshTokenHash: hashToken(refreshTokenRaw),
      expiresAt,
      userAgent: req.get("user-agent") ?? undefined,
      ip: req.ip,
    })
  );

  res.json({
    accessToken: signAccessToken(user.id),
    refreshToken: refreshTokenRaw,
    user: { id: user.id, email: user.email, fullName: user.full_name },
  });
}));

app.post("/auth/refresh", ah(async (req, res) => {
  const { refreshToken } = req.body ?? {};
  if (typeof refreshToken !== "string") return res.status(400).json({ error: "refreshToken is required" });

  // v_session_lookup (012_session_lookup.sql) — unscoped by design,
  // since the caller doesn't know their own user_id at this point.
  const session = await findActiveSessionByTokenHash(pool, hashToken(refreshToken));
  if (!session) return res.status(401).json({ error: "invalid or expired refresh token" });

  res.json({ accessToken: signAccessToken(session.user_id) });
}));

app.post("/auth/logout", ah(async (req, res) => {
  const { refreshToken } = req.body ?? {};
  if (typeof refreshToken !== "string") return res.status(400).json({ error: "refreshToken is required" });

  const session = await findActiveSessionByTokenHash(pool, hashToken(refreshToken));
  if (session) {
    // Now that we know session.user_id from the lookup, the actual
    // mutation goes back through the row-scoped v_my_sessions view.
    await withUserContext(pool, session.user_id, (conn: PoolConnection) =>
      revokeSession(conn, session.id)
    );
  }

  res.status(204).end();
}));

function requireAuth(req: express.Request, res: express.Response, next: express.NextFunction) {
  const header = req.get("authorization");
  if (!header?.startsWith("Bearer ")) return res.status(401).json({ error: "missing bearer token" });
  try {
    const payload = jwt.verify(header.slice(7), JWT_SECRET) as { sub: string };
    (req as any).userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: "invalid or expired token" });
  }
}

// Demonstrates the row-scoped view pattern end to end: the JWT proves
// who's asking, withUserContext() scopes the connection to exactly
// that user, and v_my_profile makes it structurally impossible for
// this query to return anyone else's row.
app.get("/me", requireAuth, ah(async (req, res) => {
  const userId = (req as any).userId as string;
  const profile = await withUserContext(pool, userId, async (conn: PoolConnection) => {
    const [rows] = await conn.query(
      "SELECT id, email, username, full_name, created_at FROM v_my_profile LIMIT 1"
    );
    return (rows as any[])[0] ?? null;
  });
  if (!profile) return res.status(404).json({ error: "user not found" });
  res.json(profile);
}));

// 404 for anything unmatched, before the error handler.
app.use((_req, res) => {
  res.status(404).json({ error: "not found" });
});

// Centralized error handler — this is where ah()'s .catch(next) ends
// up. Never leak err.message/stack to the client (avoids echoing SQL
// or internal details); always log it server-side.
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error("Unhandled request error:", err);
  if (res.headersSent) return;
  res.status(500).json({ error: "internal server error" });
});

const server = app.listen(PORT, () => {
  console.log(`Example API listening on http://localhost:${PORT}`);
});

// Last-resort safety net. With every route wrapped in ah(), this
// should never fire from request handling — but it protects against
// mistakes in code added later (a forgotten ah(), a rejected promise
// in a timer/event callback, etc.) turning into a silent process
// crash instead of a logged, recoverable event.
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled promise rejection:", reason);
});
process.on("uncaughtException", (err) => {
  console.error("Uncaught exception:", err);
});

// Graceful shutdown: stop accepting new connections, let in-flight
// requests finish, then close the pool — avoids dropping requests or
// leaking connections on redeploy/container stop.
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, () => {
    console.log(`${signal} received, shutting down gracefully...`);
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
  });
}
