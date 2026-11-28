INSERT INTO messages
  (id, list_id, subject, from_address, date_epoch, parent_id,
   thread_root_id, body, checksum)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
