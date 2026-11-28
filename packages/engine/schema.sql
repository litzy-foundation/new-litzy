CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  list_id TEXT NOT NULL,
  subject TEXT NOT NULL,
  from_address TEXT NOT NULL,
  date_epoch INTEGER NOT NULL,
  parent_id TEXT,
  thread_root_id TEXT NOT NULL,
  body TEXT NOT NULL,
  checksum TEXT NOT NULL,
  quarantined INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS messages_thread
ON messages (thread_root_id, parent_id);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
USING fts5(id UNINDEXED, subject, body);

CREATE TABLE IF NOT EXISTS list_policies (
  list_id TEXT PRIMARY KEY,
  action TEXT NOT NULL,
  folder TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS purge_preparations (
  id TEXT PRIMARY KEY,
  list_id TEXT NOT NULL,
  digest TEXT NOT NULL,
  consumed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS quarantine_entries (
  message_id TEXT PRIMARY KEY,
  quarantined_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_cursors (
  channel_id TEXT PRIMARY KEY,
  cursor TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS drafts (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS channels (
  id TEXT PRIMARY KEY,
  list_id TEXT NOT NULL,
  label TEXT NOT NULL,
  protocol TEXT NOT NULL,
  endpoint TEXT NOT NULL
);
