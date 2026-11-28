// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'app_asset_keys.dart';
import 'configuration_exception.dart';

/// Declarative colours and fonts used by the reading panes.
final class ThemeConfig {
  /// Creates theme tokens with the given [values].
  const ThemeConfig({
    required this.monospaceFont,
    required this.diffColor,
    required this.quoteColor,
  });

  /// Reads theme tokens from [bundle], or from the root asset bundle.
  static Future<ThemeConfig> load([AssetBundle? bundle]) async {
    final selected = bundle ?? rootBundle;
    final source = await selected.loadString(AppAssetKeys.theme);
    return ThemeConfig.fromYaml(source);
  }

  /// Parses a versioned theme document.
  factory ThemeConfig.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap || document['version'] != 1) {
      throw const ConfigurationException('version', 'is not supported');
    }
    return ThemeConfig(
      monospaceFont: _string(document, 'monospace_font'),
      diffColor: _color(document, 'diff_color'),
      quoteColor: _color(document, 'quote_color'),
    );
  }

  static String _string(YamlMap document, String key) {
    final value = document[key];
    if (value is! String || value.isEmpty) {
      throw ConfigurationException(key, 'must be a non-empty string');
    }
    return value;
  }

  static Color _color(YamlMap document, String key) {
    final value = _string(document, key);
    final parsed = int.tryParse(value.replaceFirst('#', '0x'));
    if (parsed == null) {
      throw ConfigurationException(key, 'must be an ARGB hex colour');
    }
    return Color(parsed);
  }

  /// Font family used for patch payloads.
  final String monospaceFont;

  /// Colour used for patch text.
  final Color diffColor;

  /// Colour used for quoted context text.
  final Color quoteColor;
}
