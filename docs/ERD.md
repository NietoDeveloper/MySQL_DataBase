# Entity Relationship Diagram

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : assigned_to
    ROLES ||--o{ ROLE_PERMISSIONS : has
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : granted_via
    USERS ||--o{ SESSIONS : opens
    USERS ||--o{ NOTIFICATIONS : receives

`SESSIONS`, `NOTIFICATIONS`, `USER_SETTINGS`, and `USERS` itself are exposed
to the application role only through row-scoped views
(`v_my_sessions`, `v_my_notifications`, `v_my_settings`, `v_my_profile`) —
see `docs/SECURITY.md` for why, since MySQL has no native Row-Level Security.
