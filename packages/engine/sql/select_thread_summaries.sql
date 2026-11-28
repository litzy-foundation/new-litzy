SELECT m.thread_root_id AS root_id,
       m.list_id AS list_id,
       (SELECT subject FROM messages r
        WHERE r.thread_root_id = m.thread_root_id
        ORDER BY r.date_epoch, r.id LIMIT 1) AS subject,
       COUNT(*) AS message_count,
       MAX(m.date_epoch) AS last_activity_epoch
FROM messages m
WHERE ? IS NULL OR m.list_id =
  (SELECT list_id FROM channels WHERE id = ?)
GROUP BY m.thread_root_id, m.list_id
ORDER BY last_activity_epoch DESC, root_id
