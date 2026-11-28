// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Finds the Litzy root from the current test working directory.
Directory _litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains('- packages/engine')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('the Litzy root was not found');
    }
    directory = parent;
  }
}

/// Removes block and line comments before the inline statement check.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp('//[^${TextTokens.lineFeed}]*'), '');

/// Reads detection patterns from declarative configuration.
List<RegExp> _patterns(Directory root) {
  final path =
      '${root.path}${Platform.pathSeparator}data'
      '${Platform.pathSeparator}quality${Platform.pathSeparator}'
      'sql_guard.yaml';
  final document = loadYaml(File(path).readAsStringSync()) as YamlMap;
  return (document['patterns'] as YamlList)
      .map((value) => RegExp(value as String, caseSensitive: false))
      .toList(growable: false);
}

void main() {
  final root = _litzyRoot();

  test('every declared resource key resolves to a non-empty statement', () {
    final keys = File(
      '${root.path}${Platform.pathSeparator}packages${Platform.pathSeparator}'
      'engine${Platform.pathSeparator}lib${Platform.pathSeparator}src'
      '${Platform.pathSeparator}storage${Platform.pathSeparator}'
      'sql_keys.dart',
    ).readAsStringSync();
    final names = RegExp(r"static const String \w+ =\s*'([^']+\.sql)'")
        .allMatches(keys)
        .map((match) => match.group(1)!)
        .toList();

    expect(names, isNotEmpty);
    for (final name in names) {
      expect(SqlResources.statement(name), isNotEmpty, reason: name);
    }
  });

  test('the vacuum statement escapes quotes in the destination path', () {
    final statement = SqlResources.vacuumInto('/tmp/o\'brien.db');

    expect(statement, contains("'/tmp/o''brien.db'"));
  });

  test('no statement is embedded in Dart source', () {
    final patterns = _patterns(root);
    final violations = <String>[];
    final packages = Directory('${root.path}${Platform.pathSeparator}packages');

    for (final file in packages.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (file.path.endsWith(
        '${Platform.pathSeparator}sql_resources_test.dart',
      )) {
        continue;
      }
      final normalized = file.path.replaceAll(r'\', '/');
      if (normalized.contains('/.dart_tool/') ||
          normalized.contains('/build/') ||
          normalized.contains('/ephemeral/') ||
          normalized.contains('/.plugin_symlinks/')) {
        continue;
      }
      final source = _withoutComments(file.readAsStringSync());
      for (final pattern in patterns) {
        if (pattern.hasMatch(source)) {
          violations.add('${file.path}: ${pattern.pattern}');
          break;
        }
      }
    }

    expect(violations, isEmpty);
  });
}
