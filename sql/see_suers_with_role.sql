-- ee users with role
SELECT
    u.user_id,
    u.username,
    u.first_name,
    u.last_name,
    u.email,
    r.name AS role_name
FROM
    users u
JOIN
    user_roles ur ON u.user_id = ur.user_id
JOIN
    roles r ON ur.role_id = r.id;