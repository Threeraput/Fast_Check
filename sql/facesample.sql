SELECT
    u.user_id,
    u.username,
    s.sample_id,
    encode(s.face_embedding, 'base64') AS embedding_base64
FROM public.user_face_samples s
JOIN public.users u
    ON s.user_id = u.user_id
ORDER BY s.sample_id ASC;