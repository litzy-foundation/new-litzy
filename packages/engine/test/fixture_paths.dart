// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

/// Finds the workspace root from the current test working directory.
Directory litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final defaults =
        '${directory.path}${Platform.pathSeparator}data'
        '${Platform.pathSeparator}catalog${Platform.pathSeparator}default.yaml';
    if (File(defaults).existsSync()) return directory;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('the Litzy root was not found');
}

/// Reads a versioned fixture by its file name under `data/fixtures`.
String fixtureText(String name) => File(
  '${litzyRoot().path}${Platform.pathSeparator}data'
  '${Platform.pathSeparator}fixtures${Platform.pathSeparator}$name',
).readAsStringSync();
