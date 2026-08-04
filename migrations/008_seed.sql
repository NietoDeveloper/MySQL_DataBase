-- =====================================================================
-- 008_seed.sql
-- Minimal baseline data so the schema is usable out of the box.
-- =====================================================================

INSERT IGNORE INTO roles (name, description) VALUES
    ('admin', 'Full system access'),
    ('user',  'Standard authenticated user');

INSERT IGNORE INTO permissions (code, description) VALUES
    ('users.read',     'View users'),
    ('users.write',    'Create/update/delete users'),
    ('settings.read',  'View settings'),
    ('settings.write', 'Modify settings');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = 'admin';

