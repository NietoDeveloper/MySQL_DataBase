# Connecting a Frontend to This Database

## The one rule that matters

**A frontend — a browser tab running React, Vue, plain JS, whatever —
never connects to MySQL directly.** No browser JavaScript library can
hold a database password without exposing it to everyone who opens
DevTools, and MySQL doesn't speak HTTP, so there's no URL a `fetch()`
call could even hit. This isn't a limitation of this particular
schema; it's true of every SQL database, always.

The correct — and only — architecture is:

```
┌──────────┐        HTTPS / JSON        ┌──────────────┐      TCP + TLS      ┌─────────┐
│ Frontend │  ────────────────────────► │  Your Backend │ ──────────────────► │  MySQL  │
│ (browser)│  ◄──────────────────────── │  (this repo's │ ◄────────────────── │ (this   │
└──────────┘        JWT-protected       │  client + API)│                     │  repo)  │
                                          └──────────────┘
```

This repo ships both halves of the backend side so you don't have to
build them from scratch:

- **`client/`** — a small TypeScript package (`mysql-database-client`)
  that wraps connection pooling, the row-scoped view pattern, and the
  auth-related queries (find user, create session, lockout checks,
  etc.) into typed functions. Your backend imports this.
- **`examples/express-api/`** — a complete, runnable Express REST API
  built on top of `client/`, with registration, login, JWT refresh,
  logout, and a protected `/me` endpoint. This is what your frontend
  actually talks to. Treat it as a reference to copy from, not
  something you deploy verbatim — see the "Before production" section
  in `examples/express-api/README.md`... actually there isn't one; the
  caveats live in the file header of `src/server.ts`. Read it before
  using this in anything real.

## Quick start: run the whole stack locally

```bash
cp .env.example .env
# fill in MYSQL_ROOT_PASSWORD, then:
docker compose up -d                       # starts MySQL, applies migrations 001-012
export MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=root \
       MYSQL_PASSWORD=<your MYSQL_ROOT_PASSWORD> MYSQL_DATABASE=functional_db
export APP_DB_PASSWORD=$(openssl rand -base64 32)
./scripts/create_app_role.sh               # provisions app_user

# add APP_DB_PASSWORD and a JWT_SECRET to .env, then:
docker compose --profile with-api up -d --build   # builds & starts the example API
curl http://localhost:4000/health                  # {"status":"ok"}
```

Your frontend (running on, say, `http://localhost:5173` — set
`CORS_ORIGIN` in `.env` to match) now talks to
`http://localhost:4000`, never to port 3306.

## Calling the API from a frontend

Plain `fetch`, works the same in React/Vue/Svelte/vanilla JS:

```js
// Register
await fetch("http://localhost:4000/auth/register", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email, password, fullName }),
});

// Log in — store accessToken in memory (NOT localStorage, see below),
// store refreshToken however your app persists sessions.
const { accessToken, refreshToken, user } = await fetch(
  "http://localhost:4000/auth/login",
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  }
).then((r) => r.json());

// Authenticated request
const me = await fetch("http://localhost:4000/me", {
  headers: { Authorization: `Bearer ${accessToken}` },
}).then((r) => r.json());

// Refresh when the access token expires (short-lived, e.g. 15m)
const { accessToken: fresh } = await fetch(
  "http://localhost:4000/auth/refresh",
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken }),
  }
).then((r) => r.json());
```

**Where to store tokens on the frontend:** keep the access token in
memory (a JS variable / React state / a store) — never `localStorage`
or `sessionStorage`, both are readable by any script on the page (XSS
risk). For the refresh token, the strongest common option is an
`HttpOnly` cookie set by your backend rather than JSON in the response
body; the example API returns it as JSON to keep the reference
implementation framework-agnostic — swap that for a cookie in your own
backend before shipping.

## Building your own backend instead of the example

You don't have to use Express. Any Node.js backend can depend on the
same `client/` package directly:

```bash
npm install file:../path/to/MySQL_DataBase/client
# or, once published: npm install mysql-database-client
```

```ts
import { getPool, withUserContext, findUserByEmail } from "mysql-database-client";

const pool = getPool(); // reads DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME from env
const user = await findUserByEmail(pool, "someone@example.com");
```

Not on Node.js? The pattern still applies — write a thin API in
whatever language your backend uses (Python/FastAPI, Go, PHP/Laravel,
etc.), following the same rules `client/` encodes:

1. Use a connection **pool**, not one connection per request.
2. Never build SQL with string concatenation — use parameterized
   queries everywhere.
3. For the four row-scoped tables (`users`, `sessions`,
   `notifications`, `user_settings`), always set
   `@app_current_user_id` and query through the `v_my_*` views — see
   `client/src/context.ts` for exactly why and the failure mode if you
   skip it.
4. Hash refresh tokens (SHA-256+) before storing them; never store the
   raw token.
5. Call `is_account_locked()` before verifying a password, and
   `register_failed_login()` / `register_successful_login()` after.

## GraphQL / tRPC / server-side rendering

Same rule, different transport: your GraphQL resolvers, tRPC
procedures, or Next.js Server Actions run on the backend/server side
of the same boundary diagram above — they can import `client/`
directly (they're not "the frontend" in the sense this document means,
even though they might live in the same repo as your UI code). What
must never happen is a database credential shipped into browser-
executed JavaScript, by any framework, ever.

## Local network vs. production

- **Local dev:** `docker-compose.yml` binds MySQL to `127.0.0.1` only
  — your frontend dev server and the example API can both reach it,
  nothing outside your machine can.
- **Production:** put the API behind HTTPS (a reverse proxy /
  managed load balancer), require TLS on the MySQL connection
  (`DB_SSL=true` + `scripts/generate_dev_certs.sh` for local testing
  of that path, real certificates in production), and never expose
  port 3306 outside your private network — see `docs/PERFORMANCE.md`
  and `SECURITY.md` for the rest of the production checklist.
