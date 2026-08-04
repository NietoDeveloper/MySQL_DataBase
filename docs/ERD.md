# Entity Relationship Diagram

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : assigned_to
    ROLES ||--o{ ROLE_PERMISSIONS : has
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : granted_via
    USERS ||--o{ SESSIONS : opens
    USERS ||--o{ NOTIFICATIONS : receives
    USERS ||--o{ USER_SETTINGS : configures
    USERS ||--o{ ATTACHMENTS : uploads
    USERS ||--o{ AUDIT_LOG : triggers

    USERS {
        char36 id PK
        varchar email
        varchar username
        varchar password_hash
        boolean is_active
        boolean is_verified
        smallint failed_login_attempts
        datetime locked_until
        datetime deleted_at
    }

    ROLES {
        smallint id PK
        varchar name
    }

    PERMISSIONS {
        smallint id PK
        varchar code
    }

    SESSIONS {
        char36 id PK
        char36 user_id FK
        char64 refresh_token_hash
        datetime expires_at
    }

    ATTACHMENTS {
        char36 id PK
        varchar owner_table
        varchar owner_id
        varchar file_url
    }

    NOTIFICATIONS {
        char36 id PK
        char36 user_id FK
        varchar type
        json metadata
    }

    AUDIT_LOG {
        bigint id PK
        varchar table_name
        varchar record_id
        enum action
        json old_data
        json new_data
    }

    APP_SETTINGS {
        varchar key PK
        json value
    }

    USER_SETTINGS {
        char36 user_id FK
        varchar key
        json value
    }
```

`ATTACHMENTS` uses a polymorphic pattern (`owner_table` + `owner_id`) so it can
attach a file to a row in **any** table without a dedicated foreign key per
entity — this is what makes the schema reusable across projects.

`SESSIONS`, `NOTIFICATIONS`, `USER_SETTINGS`, and `USERS` itself are exposed
to the application role only through row-scoped views
(`v_my_sessions`, `v_my_notifications`, `v_my_settings`, `v_my_profile`) —
see `docs/SECURITY.md` for why, since MySQL has no native Row-Level Security.
