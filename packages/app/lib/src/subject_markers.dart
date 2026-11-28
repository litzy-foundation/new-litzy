// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'app_asset_keys.dart';
import 'configuration_exception.dart';

/// Declarative prefixes recognised in mailing list subject lines.
final class SubjectMarkers {
  /// Creates a marker set with the given [patchPrefixes].
  const SubjectMarkers(this.patchPrefixes);

  /// Reads subject markers from [bundle], or from the root asset bundle.
  static Future<SubjectMarkers> load([AssetBundle? bundle]) async {
    final selected = bundle ?? rootBundle;
    final source = await selected.loadString(AppAssetKeys.subjectMarkers);
    return SubjectMarkers.fromYaml(source);
  }

  /// Parses a versioned subject marker document.
  factory SubjectMarkers.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap || document['version'] != 1) {
      throw const ConfigurationException('version', 'is not supported');
    }
    final value = document['patch_prefixes'];
    if (value is! YamlList || value.isEmpty) {
      throw const ConfigurationException(
        'patch_prefixes',
        'must list at least one prefix',
      );
    }
    final prefixes = value.toList().whereType<String>().toList();
    if (prefixes.isEmpty || prefixes.any((prefix) => prefix.isEmpty)) {
      throw const ConfigurationException(
        'patch_prefixes',
        'must contain non-empty prefixes',
      );
    }
    return SubjectMarkers(List<String>.unmodifiable(prefixes));
  }

  /// Prefixes that identify a patch series.
  final List<String> patchPrefixes;

  /// Whether [subject] announces a patch.
  bool isPatch(String subject) =>
      patchPrefixes.any(subject.trimLeft().startsWith);
}
