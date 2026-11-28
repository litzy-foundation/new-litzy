INSERT INTO list_policies (list_id, action, folder) VALUES (?, ?, ?)
ON CONFLICT(list_id) DO UPDATE SET
  action = excluded.action, folder = excluded.folder
