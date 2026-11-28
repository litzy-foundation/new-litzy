INSERT INTO accounts
  (id, email, imap_host, imap_port, smtp_host, smtp_port, authentication, list_id, created_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  email = excluded.email,
  imap_host = excluded.imap_host,
  imap_port = excluded.imap_port,
  smtp_host = excluded.smtp_host,
  smtp_port = excluded.smtp_port,
  authentication = excluded.authentication,
  list_id = excluded.list_id
