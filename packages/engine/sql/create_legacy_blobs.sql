-- Copyright (c) 2026 Alessio Attilio and the litzy contributors
-- Legacy layout used by migration tests.
CREATE TABLE blobs (
  digest TEXT PRIMARY KEY,
  codec TEXT NOT NULL,
  size INTEGER NOT NULL,
  payload BLOB NOT NULL
)
