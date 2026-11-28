// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

/// Finds the workspace root from the current test working directory.
Directory litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains('- packages/l10n')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('the Litzy root was not found');
}

/// Reads a versioned resource by its path under the workspace root.
String resourceText(String relativePath) =>
    File('${litzyRoot().path}${Platform.pathSeparator}$relativePath')
        .readAsStringSync();
