INSERT INTO sync_cursors (channel_id, cursor) VALUES (?, ?)
ON CONFLICT(channel_id) DO UPDATE SET cursor = excluded.cursor
