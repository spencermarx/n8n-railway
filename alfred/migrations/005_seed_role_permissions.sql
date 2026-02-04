-- Alfred Migration 005: Seed Role Permissions
-- Default permissions for admin, member, and guest roles
-- Safe to run multiple times (ON CONFLICT DO NOTHING)

INSERT INTO alfred.role_permissions (role, permissions) VALUES
('admin', '{
    "calendar_read": true,
    "calendar_write": true,
    "email_read": true,
    "email_send": true,
    "email_delete": true,
    "docs_read": true,
    "docs_write": true,
    "docs_create": true,
    "sheets_read": true,
    "sheets_write": true,
    "drive_read": true,
    "drive_write": true,
    "drive_share": true,
    "tasks_read": true,
    "tasks_write": true,
    "research_web": true,
    "workflows_view": true,
    "workflows_create": true,
    "workflows_activate": true,
    "workflows_delete": true,
    "admin_manage_users": true,
    "admin_view_all_data": true
}'::jsonb),
('member', '{
    "calendar_read": true,
    "calendar_write": true,
    "email_read": true,
    "email_send": true,
    "email_delete": false,
    "docs_read": true,
    "docs_write": true,
    "docs_create": true,
    "sheets_read": true,
    "sheets_write": true,
    "drive_read": true,
    "drive_write": true,
    "drive_share": false,
    "tasks_read": true,
    "tasks_write": true,
    "research_web": true,
    "workflows_view": true,
    "workflows_create": false,
    "workflows_activate": false,
    "workflows_delete": false,
    "admin_manage_users": false,
    "admin_view_all_data": false
}'::jsonb),
('guest', '{
    "calendar_read": true,
    "calendar_write": false,
    "email_read": false,
    "email_send": false,
    "email_delete": false,
    "docs_read": true,
    "docs_write": false,
    "docs_create": false,
    "sheets_read": true,
    "sheets_write": false,
    "drive_read": true,
    "drive_write": false,
    "drive_share": false,
    "tasks_read": true,
    "tasks_write": false,
    "research_web": true,
    "workflows_view": false,
    "workflows_create": false,
    "workflows_activate": false,
    "workflows_delete": false,
    "admin_manage_users": false,
    "admin_view_all_data": false
}'::jsonb)
ON CONFLICT (role) DO NOTHING;

-- Verify seed data
SELECT role, permissions
FROM alfred.role_permissions
ORDER BY role;
