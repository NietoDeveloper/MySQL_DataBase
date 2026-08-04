-- =====================================================================
-- 008_seed.sql
-- Minimal baseline data so the schema is usable out of the box.
-- =====================================================================

INSERT IGNORE INTO roles (name, description) VALUES
    ('admin', 'Full system access'),
    ('user',  'Standard authenticated user');
