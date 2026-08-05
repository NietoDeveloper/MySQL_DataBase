/**
 * withUserContext() is the single most important function in this
 * package. docs/SECURITY.md in the main repo flags the real risk with
 * MySQL's session-variable-based row scoping: @app_current_user_id is
 * tied to the CONNECTION, not the transaction, so a pooled connection
 * that "forgets" to reset it can leak one user's context into the next
 * request that happens to reuse that connection.
 *
 * This helper removes the footgun: it checks out one dedicated
 * connection from the pool, sets @app_current_user_id, runs your
 * queries against the row-scoped views (v_my_profile, v_my_sessions,
 * v_my_notifications, v_my_settings), then ALWAYS clears the variable
 * and releases the connection back to the pool — even if your callback
 * throws. Never query those views through pool.query() directly;
 * always go through this function.
 */
import { Pool, PoolConnection } from "mysql2/promise";

export async function withUserContext<T>(
  pool: Pool,
  userId: string,
  fn: (conn: PoolConnection) => Promise<T>
): Promise<T> {
  const conn = await pool.getConnection();
  try {
    await conn.query("SET @app_current_user_id = ?", [userId]);
    return await fn(conn);
  } finally {
    // Always clear it — this is what stops context bleeding into the
    // next request that reuses this pooled connection.
    await conn.query("SET @app_current_user_id = NULL");
    conn.release();
  }
}

/**
 * For admin/back-office code paths that intentionally use the
 * app_admin role (direct table access, bypassing the row-scoped
 * views). Use sparingly and only where you've deliberately decided the
 * caller is trusted to see every row — see docs/SECURITY.md.
 */
export async function withAdminContext<T>(
  pool: Pool,
  fn: (conn: PoolConnection) => Promise<T>
): Promise<T> {
  const conn = await pool.getConnection();
  try {
    return await fn(conn);
  } finally {
    conn.release();
  }
}
