/**
 * Single entry point for the package (`import { ... } from "mysql-database-client"`).
 * Re-exports the pool factory and the context-scoping helpers so
 * consumers never need to know the internal file layout.
 */
export { getPool, closePool, loadConfigFromEnv } from "./pool";
export type { DbConfig } from "./pool";
export { withUserContext, withAdminContext } from "./context";
export {
  findUserByEmail,
  findUserById,
  createUser,
  createSession,
  findActiveSessionByTokenHash,
  revokeSession,
  recordFailedLogin,
  recordSuccessfulLogin,
  isAccountLocked,
} from "./queries";
export type { NewUserInput, UserRow } from "./queries";
