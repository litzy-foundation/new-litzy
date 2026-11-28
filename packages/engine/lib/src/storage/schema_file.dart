// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Locates and splits the versioned SQLite schema file.
///
/// Keeping the schema outside Dart satisfies R47. The loader checks the
/// locations used by source runs, package tests and a compiled binary next to
/// its schema file, and fails explicitly when none is present.
library;

import 'dart:io';

/// Reads the statements from `schema.sql` shipped with the engine package.
final class SchemaFile {
  const SchemaFile._();

  /// File name of the schema beside the engine package sources.
  static const String name = 'schema.sql';

  /// Package-relative location used from the workspace root.
  static const String packageLocation = 'packages/engine/$name';

  /// Sibling package location used when another package owns the working
  /// directory.
  static const String siblingLocation = '../engine/$name';

  /// Separator between statements in the schema file.
  static const String statementSeparator = ';';

  /// Returns the schema statements in file order.
  static List<String> statements() {
    final file = _locate();
    return file
        .readAsStringSync()
        .split(statementSeparator)
        .map((statement) => statement.trim())
        .where((statement) => statement.isNotEmpty)
        .toList(growable: false);
  }

  static File _locate() {
    final candidates = <File>[
      File.fromUri(Platform.script.resolve(name)),
      File.fromUri(Platform.script.resolve('../$name')),
      File(name),
      File(packageLocation),
      File(siblingLocation),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate;
    }
    throw StateError('the engine schema file is missing');
  }
}
