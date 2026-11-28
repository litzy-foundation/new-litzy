// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'app_asset_keys.dart';
import 'configuration_exception.dart';

/// Declarative Quiet Workshop tokens used by every Litzy surface.
///
/// ADR-0026 requires one token file for all targets, so widgets refer to these
/// values instead of literal colours, sizes or motion durations.
final class ThemeConfig {
  /// Creates theme tokens with the given [values].
  const ThemeConfig({
    required this.styleName,
    required this.monospaceFont,
    required this.surfaceColor,
    required this.surfaceAltColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.accentColor,
    required this.borderColor,
    required this.diffColor,
    required this.quoteColor,
    required this.spacingUnit,
    required this.cardRadius,
    required this.bodyTextScale,
    required this.focusWidth,
    required this.reducedMotion,
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
      styleName: _string(document, 'style_name'),
      monospaceFont: _string(document, 'monospace_font'),
      surfaceColor: _color(document, 'surface_color'),
      surfaceAltColor: _color(document, 'surface_alt_color'),
      textColor: _color(document, 'text_color'),
      mutedTextColor: _color(document, 'muted_text_color'),
      accentColor: _color(document, 'accent_color'),
      borderColor: _color(document, 'border_color'),
      diffColor: _color(document, 'diff_color'),
      quoteColor: _color(document, 'quote_color'),
      spacingUnit: _positive(document, 'spacing_unit'),
      cardRadius: _positive(document, 'card_radius'),
      bodyTextScale: _positive(document, 'body_text_scale'),
      focusWidth: _positive(document, 'focus_width'),
      reducedMotion: Duration(
        milliseconds: _nonNegativeInteger(document, 'reduced_motion_ms'),
      ),
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

  static double _positive(YamlMap document, String key) {
    final value = document[key];
    if (value is! num || value <= 0) {
      throw ConfigurationException(key, 'must be a positive number');
    }
    return value.toDouble();
  }

  static int _nonNegativeInteger(YamlMap document, String key) {
    final value = document[key];
    if (value is! int || value < 0) {
      throw ConfigurationException(key, 'must be a non-negative integer');
    }
    return value;
  }

  /// Declared name of the visual style.
  final String styleName;

  /// Font family used for patch payloads.
  final String monospaceFont;

  /// Colour of primary surfaces.
  final Color surfaceColor;

  /// Colour of alternating surfaces.
  final Color surfaceAltColor;

  /// Primary reading colour.
  final Color textColor;

  /// Colour of secondary labels.
  final Color mutedTextColor;

  /// Accent reserved for unread and activity state.
  final Color accentColor;

  /// Colour of separators and outlines.
  final Color borderColor;

  /// Colour used for patch text.
  final Color diffColor;

  /// Colour used for quoted context text.
  final Color quoteColor;

  /// Base unit for all spacing.
  final double spacingUnit;

  /// Radius used by cards and panes.
  final double cardRadius;

  /// Scale applied to reading text.
  final double bodyTextScale;

  /// Width of the keyboard focus outline.
  final double focusWidth;

  /// Duration used when the system requests reduced motion.
  final Duration reducedMotion;
}
