SELECT
  id,
  email,
  imap_host,
  imap_port,
  smtp_host,
  smtp_port,
  authentication,
  list_id,
  created_at
FROM accounts
ORDER BY id
