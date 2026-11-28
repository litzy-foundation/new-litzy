// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'app_asset_keys.dart';
import 'configuration_exception.dart';

/// Declarative measurements used by the adaptive reading layout.
final class LayoutConfig {
  /// Creates a layout configuration with the given [values].
  const LayoutConfig({
    required this.desktopMinWidth,
    required this.channelPaneWidth,
    required this.threadPaneWidth,
    required this.threadIndent,
    required this.cardPadding,
  });

  /// Reads layout values from [bundle], or from the root asset bundle.
  static Future<LayoutConfig> load([AssetBundle? bundle]) async {
    final selected = bundle ?? rootBundle;
    final source = await selected.loadString(AppAssetKeys.layout);
    return LayoutConfig.fromYaml(source);
  }

  /// Parses a versioned layout document.
  factory LayoutConfig.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap || document['version'] != 1) {
      throw const ConfigurationException('version', 'is not supported');
    }
    return LayoutConfig(
      desktopMinWidth: _integer(document, 'desktop_min_width'),
      channelPaneWidth: _integer(document, 'channel_pane_width'),
      threadPaneWidth: _integer(document, 'thread_pane_width'),
      threadIndent: _integer(document, 'thread_indent'),
      cardPadding: _integer(document, 'card_padding'),
    );
  }

  static int _integer(YamlMap document, String key) {
    final value = document[key];
    if (value is! int) {
      throw ConfigurationException(key, 'must be an integer');
    }
    return value;
  }

  /// Width at which the desktop layout replaces the mobile stack.
  final int desktopMinWidth;

  /// Width of the channel pane in the desktop layout.
  final int channelPaneWidth;

  /// Width of the conversation pane in the desktop layout.
  final int threadPaneWidth;

  /// Horizontal space added for each reply branch.
  final int threadIndent;

  /// Padding around one message card.
  final int cardPadding;
}
