WITH RECURSIVE subtree (id, depth) AS (
  SELECT id, 0 FROM messages WHERE id = ?
  UNION ALL
  SELECT m.id, s.depth + 1
  FROM messages m
  JOIN subtree s ON m.parent_id = s.id
  WHERE s.depth < ?
)
SELECT m.* FROM messages m
JOIN subtree s ON m.id = s.id
ORDER BY s.depth, m.date_epoch
