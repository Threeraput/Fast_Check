-- SQL to add a user with Admin role
-- Note: Replace the values with your actual data

-- Step 1: Insert a new user (password should be hashed using bcrypt first)
-- You can generate UUID using: SELECT gen_random_uuid() in PostgreSQL
-- Password hash example is for: 'admin123' (use bcrypt to generate real hash)

INSERT INTO users (
    user_id,
    username,
    password_hash,
    email,
    first_name,
    last_name,
    is_active,
    is_approved,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),  -- PostgreSQL function to generate UUID
    'admin_user',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lm',  -- bcrypt hash of password
    'admin@example.com',
    'Admin',
    'User',
    true,
    true,
    NOW(),
    NOW()
);

-- Step 2: Assign Admin role to the user
-- First, get the admin role id:
INSERT INTO user_roles (user_id, role_id)
SELECT 
    u.user_id,
    r.id
FROM 
    users u,
    roles r
WHERE 
    u.username = 'admin_user'
    AND r.name = 'admin';

-- Verify the user was created with role:
SELECT
    u.user_id,
    u.username,
    u.email,
    r.name AS role_name
FROM
    users u
JOIN
    user_roles ur ON u.user_id = ur.user_id
JOIN
    roles r ON ur.role_id = r.id
WHERE
    u.username = 'admin_user';
