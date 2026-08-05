/**
 * Thin, parameterized repository functions over the schema in
 * ../../migrations. These are the building blocks a real auth service
 * is made of — every query here uses placeholders (`?`), never string
 * interpolation, so this file is also the reference example for
 * avoiding SQL injection when you add your own queries.
 *
 * None of these functions hash passwords or issue JWTs — that's
 * intentionally left to the caller (see ../examples/server.ts for a
 * complete example) so this package has zero opinion on your auth
 * library of choice (bcrypt vs argon2, jsonwebtoken vs jose, etc.).
 */
import type { Pool, PoolConnection, RowDataPacket, ResultSetHeader } from "mysql2/promise";

export interface UserRow extends RowDataPacket {
  id: string;
  email: string;
  username: string | null;
  password_hash: string;
  full_name: string | null;
  is_active: boolean;
  is_verified: boolean;
  failed_login_attempts: number;
  locked_until: Date | null;
  deleted_at: Date | null;
}

export interface NewUserInput {
  email: string;
  username?: string;
  passwordHash: string; // hash it BEFORE calling this (bcrypt/argon2) — never pass a plaintext password
  fullName?: string;
}

/** Runnable against either a Pool or a checked-out PoolConnection. */
type Runner = Pool | PoolConnection;

export async function findUserByEmail(db: Runner, email: string): Promise<UserRow | null> {
  // v_auth_lookup, not the `users` table directly — see
  // ../../migrations/011_auth_surface.sql for why app_rw only has
  // access to this narrow view for pre-authentication lookups.
  const [rows] = await db.query<UserRow[]>(
    "SELECT * FROM v_auth_lookup WHERE email = ? LIMIT 1",
    [email]
  );
  return rows[0] ?? null;
}

export async function findUserById(db: Runner, id: string): Promise<UserRow | null> {
  const [rows] = await db.query<UserRow[]>(
    "SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1",
    [id]
  );
  return rows[0] ?? null;
}

export async function createUser(db: Runner, input: NewUserInput): Promise<string> {
  // v_auth_registration restricts the INSERT to exactly the columns a
  // sign-up form should set — see ../../migrations/011_auth_surface.sql.
  const [result] = await db.query<ResultSetHeader>(
    `INSERT INTO v_auth_registration (id, email, username, password_hash, full_name)
     VALUES (UUID(), ?, ?, ?, ?)`,
    [input.email, input.username ?? null, input.passwordHash, input.fullName ?? null]
  );
  // MySQL doesn't support INSERT ... RETURNING, so re-read the row we
  // just inserted rather than trying to derive the UUID client-side.
  const [rows] = await db.query<UserRow[]>(
    "SELECT id FROM v_auth_lookup WHERE email = ? LIMIT 1",
    [input.email]
  );
  if (!rows[0]) throw new Error("createUser: insert succeeded but row was not found on re-read");
  return rows[0].id;
}

/**
 * Must be called with `db` already scoped to the session's owner —
 * i.e. from inside withUserContext(pool, userId, conn => createSession(conn, ...)).
 * Inserts through v_my_sessions (not the base `sessions` table, which
 * app_rw has no direct grant on — see 009_security_hardening.sql) so
 * the WITH CASCADED CHECK OPTION on the view guarantees the row's
 * user_id can only ever be the caller's own id.
 */
export async function createSession(
  db: Runner,
  params: { userId: string; refreshTokenHash: string; expiresAt: Date; userAgent?: string; ip?: string }
): Promise<void> {
  await db.query(
    `INSERT INTO v_my_sessions (id, user_id, refresh_token_hash, user_agent, ip_address, expires_at)
     VALUES (UUID(), ?, ?, ?, ?, ?)`,
    [params.userId, params.refreshTokenHash, params.userAgent ?? null, params.ip ?? null, params.expiresAt]
  );
}

interface SessionRow extends RowDataPacket {
  id: string;
  user_id: string;
  expires_at: Date;
  revoked_at: Date | null;
}

/**
 * Pre-auth lookup: the caller only has a raw token, not a user_id, so
 * this deliberately queries v_session_lookup (unscoped, SELECT-only —
 * see 012_session_lookup.sql) rather than v_my_sessions.
 */
export async function findActiveSessionByTokenHash(
  db: Runner,
  refreshTokenHash: string
): Promise<SessionRow | null> {
  const [rows] = await db.query<SessionRow[]>(
    `SELECT * FROM v_session_lookup
     WHERE refresh_token_hash = ? AND revoked_at IS NULL AND expires_at > NOW()
     LIMIT 1`,
    [refreshTokenHash]
  );
  return rows[0] ?? null;
}

/**
 * Must be called with `db` already scoped to the session owner (i.e.
 * from inside withUserContext(pool, session.user_id, ...)) — mutates
 * through v_my_sessions, same reasoning as createSession() above.
 */
export async function revokeSession(db: Runner, sessionId: string): Promise<void> {
  await db.query("UPDATE v_my_sessions SET revoked_at = NOW() WHERE id = ?", [sessionId]);
}

/** Wraps the register_failed_login() procedure from 007_triggers_procedures.sql. */
export async function recordFailedLogin(
  db: Runner,
  userId: string,
  maxAttempts = 5,
  lockMinutes = 15
): Promise<void> {
  await db.query("CALL register_failed_login(?, ?, ?)", [userId, maxAttempts, lockMinutes]);
}

/** Wraps register_successful_login() — call this on every successful login. */
export async function recordSuccessfulLogin(db: Runner, userId: string): Promise<void> {
  await db.query("CALL register_successful_login(?)", [userId]);
}

/** Wraps is_account_locked() — check this BEFORE verifying a password, not after. */
export async function isAccountLocked(db: Runner, userId: string): Promise<boolean> {
  const [rows] = await db.query<RowDataPacket[]>("SELECT is_account_locked(?) AS locked", [userId]);
  return Boolean(rows[0]?.locked);
}
