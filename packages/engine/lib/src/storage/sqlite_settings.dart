// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Named SQLite connection settings required by ADR-0019.
library;

/// Concurrency settings applied before every schema access.
final class SqliteSettings {
  const SqliteSettings._();

  /// Write-ahead journal mode shared by the CLI and the GUI.
  static const String journalMode = 'WAL';

  /// Milliseconds SQLite waits for a busy database before failing.
  static const int busyTimeoutMilliseconds = 5000;

  /// Pragma that reads or changes the journal mode.
  static const String journalModePragma = 'journal_mode';

  /// Pragma that reads or changes the busy timeout.
  static const String busyTimeoutPragma = 'busy_timeout';
}
