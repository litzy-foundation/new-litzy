// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Loads SQL statements from standalone resources beside the engine package.
///
/// Code selects a statement only by a key from `SqlKeys`, as required by R51.
/// The search order covers source runs, package tests and a compiled client
/// launched from the workspace root or from a bundle beside its SQL folder.
library;

import 'dart:io';

import 'sql_keys.dart';

/// Reads one SQL statement by resource key.
final class SqlResources {
  const SqlResources._();

  /// Folder that holds the standalone statement resources.
  static const String directoryName = 'sql';

  /// Package-relative location used from the workspace root.
  static const String packageLocation = 'packages/engine/$directoryName';

  /// Sibling package location used when another package owns the working
  /// directory.
  static const String siblingLocation = '../engine/$directoryName';

  /// Marker replaced by the escaped backup path in the vacuum statement.
  static const String destinationMarker = '{{destination}}';

  /// Quote used to wrap the backup path in the vacuum statement.
  static const String quote = "'";

  /// Escaped quote used inside the backup path.
  static const String escapedQuote = "''";

  /// Returns the trimmed statement stored under [key].
  static String statement(String key) {
    if (key.isEmpty ||
        key.contains('/') ||
        key.contains(r'\') ||
        !key.endsWith('.sql')) {
      throw StateError('invalid SQL resource key: $key');
    }
    return _locate(key).readAsStringSync().trim();
  }

  /// Returns the vacuum statement with [destination] safely quoted.
  static String vacuumInto(String destination) {
    final escaped = destination.replaceAll(quote, escapedQuote);
    return statement(SqlKeys.vacuumInto).replaceAll(destinationMarker, escaped);
  }

  static File _locate(String key) {
    final relative = '$directoryName/$key';
    final candidates = <File>[
      File.fromUri(Platform.script.resolve(relative)),
      File.fromUri(Platform.script.resolve('../$relative')),
      File(relative),
      File('$packageLocation/$key'),
      File('$siblingLocation/$key'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate;
    }
    throw StateError('the SQL resource $key is missing');
  }
}
