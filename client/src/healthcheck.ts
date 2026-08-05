/**
 * Quick connectivity + sanity check: `npm run healthcheck`.
 * Confirms the pool connects, a simple query round-trips, and the
 * row-scoped view context helper works end to end. Useful as a
 * post-deploy smoke test or a Docker HEALTHCHECK for your own API
 * service built on top of this package.
 */
import "dotenv/config";
import { getPool, closePool, withUserContext } from "./db";

async function main() {
  const pool = getPool();

  const [rows] = await pool.query("SELECT 1 AS ok");
  console.log("✅ Pool connection OK:", rows);

  const [[{ VERSION }]] = (await pool.query("SELECT VERSION() AS VERSION")) as any;
  console.log(`✅ MySQL version: ${VERSION}`);

  // Exercise the context helper against a view with a UUID that will
  // simply match zero rows — proves the SET/CLEAR cycle works without
  // requiring seed data to be present.
  await withUserContext(pool, "00000000-0000-0000-0000-000000000000", async (conn) => {
    const [profileRows] = await conn.query("SELECT COUNT(*) AS n FROM v_my_profile");
    console.log("✅ Row-scoped view reachable:", profileRows);
  });

  await closePool();
  console.log("✅ All checks passed.");
}

main().catch((err) => {
  console.error("❌ Healthcheck failed:", err.message);
  process.exit(1);
});
