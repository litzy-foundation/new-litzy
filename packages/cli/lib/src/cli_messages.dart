// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Locates the versioned Fluent resource for the terminal client.
///
/// R11 requires user-visible text to come from a Fluent file. The locator
/// searches the workspace and the directories beside a compiled bundle, so a
/// missing resource fails explicitly rather than silently using a literal.
library;

import 'dart:io';

import 'package:l10n/l10n.dart';

/// Loads the typed messages used by the terminal client.
final class CliMessages {
  const CliMessages._();

  /// Reads and parses the versioned Fluent resource.
  static AppMessages read() =>
      AppMessages(FluentCatalog.parse(_locate().readAsStringSync()));

  static File _locate() {
    for (final parent in const ['', '../', '../../', '../../../']) {
      final candidate = File.fromUri(
        Platform.script.resolve('${parent}data/l10n/en.ftl'),
      );
      if (candidate.existsSync()) return candidate;
    }
    var directory = Directory.current;
    while (true) {
      final candidate = File(
        '${directory.path}${Platform.pathSeparator}data${Platform.pathSeparator}'
        'l10n${Platform.pathSeparator}en.ftl',
      );
      if (candidate.existsSync()) return candidate;
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
    throw StateError('the Fluent resource is missing');
  }
}
