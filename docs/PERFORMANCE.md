# Performance & Scalability

This document covers what's already tuned in this repo, how to size the
pieces you control, and the path to scaling beyond a single instance.

## What's already tuned

- **Composite indexes** matching the schema's actual query patterns
  (`010_performance_scalability.sql`): auth lookups
  (`email, is_active, deleted_at`), session cleanup
  (`expires_at, revoked_at`), notification inbox pagination
  (`user_id, created_at DESC`), attachment listing
  (`owner_table, owner_id, created_at DESC`). A single-column index on
  a low-selectivity boolean like `is_active` is close to useless on its
  own — every index here is composite, matching how the column is
  actually filtered alongside others.
- **Bounded housekeeping.** `sessions` and `audit_log` are the two
  tables that grow unbounded by default. `cleanup_expired_sessions()`
  runs daily via a MySQL `EVENT` (deletes in batches of 5,000 — never
  one giant transaction that locks the table). `audit_log` is
  compliance-relevant, so it is **not** auto-pruned — call
  `CALL archive_audit_log_older_than(365);` (or whatever your retention
  policy requires) on your own schedule instead.
- **InnoDB tuned for a single-instance workload** in
  `docker-compose.yml`: `innodb-buffer-pool-size=512M` (raise this to
  ~70% of the container's memory limit on a dedicated host — it's the
  single highest-impact setting for read performance), 2 buffer pool
  instances, `O_DIRECT` flush method to avoid double-buffering with the
  OS page cache, and a slow-query log (`long-query-time=1`) so
  regressions show up immediately instead of silently.
- **Connection pooling done right** in `client/src/pool.ts`: one pool
  per process (never per-request), `waitForConnections: true` so a
  burst queues instead of erroring, `keepAlive` so idle connections
  survive NAT/load-balancer idle timeouts, UTC timezone pinned so
  datetime math never depends on the pool member/host clock.

## Sizing the connection pool

Start at `connectionLimit = CPU cores × 2` on the box running your
API, then measure. Going higher doesn't reliably help past a point —
MySQL serializes on internal mutexes under enough concurrent
connections, and you'll get better throughput from a moderate pool +
`--max-connections=200` on the server (already set) than from an
oversized pool fighting itself. If you're running multiple API
instances behind a load balancer, divide your target total connection
count by the instance count, not `CPU cores × 2` per instance — that
multiplies fast.

## Read-heavy workloads: add a replica before you add complexity

Once a single MySQL instance is the bottleneck (check the slow-query
log first — a missing index is usually cheaper to fix than adding
infrastructure), the standard next step is a **read replica**:

1. Enable binary logging on the primary (`log-bin=mysql-bin`,
   `server-id=1`), point a second `mysql:8.0` container at it as a
   replica (`server-id=2`, `CHANGE REPLICATION SOURCE TO ...`).
2. Route `SELECT`s that can tolerate a few hundred ms of replication
   lag (dashboards, listings, `v_auth_lookup` for login — a small lag
   there just means a just-registered user can't log in for a moment)
   through a second pool pointed at the replica.
3. Keep every `INSERT`/`UPDATE`/`DELETE`, and any read that must be
   perfectly fresh (e.g. immediately re-reading a row you just wrote),
   on the primary.
4. `client/src/pool.ts` supports this today without changes — call
   `getPool()` twice with different `DbConfig.host` values and keep the
   two pools in separate variables (`primaryPool`, `replicaPool`) in
   your API code.

## Beyond one primary: proxying and sharding

- **ProxySQL or MySQL Router** in front of a primary + N replicas
  gives you automatic read/write splitting and connection multiplexing
  without changing application code — point `client/`'s `DB_HOST` at
  the proxy instead of MySQL directly.
- **Sharding** (splitting `users` etc. across multiple MySQL instances
  by, e.g., a hash of `id`) is a last resort, not a default — it trades
  away cross-shard joins and transactions. Nothing in this schema
  assumes a single instance, but nothing sets sharding up for you
  either; it's an application-level concern layered on top if you
  actually reach that scale.
- **Caching** in front of read-heavy, rarely-changing data
  (`app_settings`, permission lists) with Redis or an in-process LRU
  cache is usually a bigger win than any database-side change, and is
  orthogonal to everything above.

## Table growth you should plan for

| Table | Growth pattern | Mitigation already in place |
|---|---|---|
| `audit_log` | Unbounded, append-only | `archive_audit_log_older_than()` — call on your own retention schedule |
| `sessions` | Unbounded without cleanup | Auto-pruned daily via `ev_cleanup_expired_sessions` |
| `notifications` | Unbounded per user | Not auto-pruned — add your own retention call if inboxes grow large; the `(user_id, created_at DESC)` index keeps pagination fast regardless |
| `attachments` | Unbounded, one row per file | Not auto-pruned — pair with your object storage's lifecycle rules |
| `users`, `roles`, `permissions` | Bounded by real-world usage | No action needed at any realistic scale |

## Before you conclude you need to scale out

Run `EXPLAIN` on the actual slow query first. In practice, most
"MySQL is slow" reports trace back to a missing index for a *new*
query pattern this schema didn't originally anticipate (see the
`010_performance_scalability.sql` header comment on why every index
here is composite, not single-column) — add the matching composite
index before reaching for a replica, a cache, or a bigger box.
