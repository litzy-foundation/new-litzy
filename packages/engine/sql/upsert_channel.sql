INSERT INTO channels (id, list_id, label, protocol, endpoint)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  list_id = excluded.list_id,
  label = excluded.label,
  protocol = excluded.protocol,
  endpoint = excluded.endpoint
