// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'app_asset_keys.dart';
import 'configuration_exception.dart';

/// Declarative name of the local SQLite profile opened by the client.
final class ProfileConfig {
  /// Creates a profile configuration for [databasePath].
  const ProfileConfig(this.databasePath);

  /// Reads the profile configuration from [bundle], or from the root asset
  /// bundle when no bundle is supplied.
  static Future<ProfileConfig> load([AssetBundle? bundle]) async {
    final selected = bundle ?? rootBundle;
    final source = await selected.loadString(AppAssetKeys.profile);
    return ProfileConfig.fromYaml(source);
  }

  /// Parses a versioned profile configuration document.
  factory ProfileConfig.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap || document['version'] != 1) {
      throw const ConfigurationException('version', 'is not supported');
    }
    final value = document['database_file'];
    if (value is! String || value.isEmpty) {
      throw const ConfigurationException(
        'database_file',
        'must name a local SQLite file',
      );
    }
    return ProfileConfig(value);
  }

  /// Path of the SQLite file relative to the client's profile directory.
  final String databasePath;
}
