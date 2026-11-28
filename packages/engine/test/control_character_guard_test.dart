// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('production Dart source uses no raw control escape', () {
    final file = _locatePolicy();
    final document = loadYaml(file.readAsStringSync()) as YamlMap;
    expect(document['version'], 1);
    final sequences = (document['forbidden_sequences']! as YamlList)
        .map((entry) => String.fromCharCodes((entry as YamlList).cast<int>()))
        .toList();
    final paths = (document['scanned_paths']! as YamlList).cast<String>();
    final violations = <String>[];
    for (final path in paths) {
      final directory = Directory(path);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final sequence in sequences) {
          if (source.contains(sequence)) {
            violations.add('${entity.path}: $sequence');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join(', '));
  });
}

File _locatePolicy() {
  const relative = 'data/quality/control_character_guard.yaml';
  final candidates = [
    File(relative),
    File('../$relative'),
    File('../../$relative'),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate;
  }
  throw StateError('the control character guard policy is missing');
}
