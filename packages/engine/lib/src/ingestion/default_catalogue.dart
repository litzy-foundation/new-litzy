// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'catalog.dart';

/// Resolves the declarative defaults that let a front-end omit source flags.
///
/// R45 asks for credential-free reading of the Git list. Keeping the defaults
/// in YAML under `data/` preserves R2, while the engine remains the only
/// component that interprets catalogue data as required by R13.
final class DefaultCatalogue {
  /// Reads the defaults from the nearest Litzy workspace root.
  static ({String cataloguePath, String sourceId}) resolve() {
    final root = _workspaceRoot();
    final file = File(
      '${root.path}${Platform.pathSeparator}data'
      '${Platform.pathSeparator}catalog${Platform.pathSeparator}default.yaml',
    );
    if (!file.existsSync()) {
      throw const CatalogException('default catalogue file is missing');
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap || document['version'] != 1) {
      throw const CatalogException('unsupported default catalogue version');
    }
    final catalogue = _required(document, 'catalogue');
    final source = _required(document, 'source');
    final cataloguePath = Uri.directory(root.path)
        .resolve(catalogue)
        .toFilePath();
    return (cataloguePath: cataloguePath, sourceId: source);
  }

  static Directory _workspaceRoot() {
    var directory = Directory.current;
    while (true) {
      final manifest = File(
        '${directory.path}${Platform.pathSeparator}pubspec.yaml',
      );
      if (manifest.existsSync() &&
          manifest.readAsStringSync().contains('- packages/cli')) {
        return directory;
      }
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
    throw const CatalogException('the Litzy workspace root was not found');
  }

  static String _required(YamlMap document, String key) {
    final value = document[key];
    if (value is! String || value.isEmpty) {
      throw CatalogException('missing default catalogue field $key');
    }
    return value;
  }
}
