INSERT INTO drafts (id, message_id, subject, body, created_at)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  message_id = excluded.message_id,
  subject = excluded.subject,
  body = excluded.body,
  created_at = excluded.created_at
