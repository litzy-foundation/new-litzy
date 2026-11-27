// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:yaml/yaml.dart';

/// One public list reachable without an email account.
final class ListSource {
  /// Creates a catalogue entry.
  const ListSource({
    required this.id,
    required this.label,
    required this.listId,
    required this.nntpHost,
    required this.nntpPort,
    required this.newsgroup,
    required this.inboxBaseUrl,
  });

  /// Stable local identifier of the list.
  final String id;

  /// Human-readable label.
  final String label;

  /// RFC 2369 list identifier used by the trust chain.
  final String listId;

  /// NNTP host, or an empty string when only public-inbox is available.
  final String nntpHost;

  /// NNTP port.
  final int nntpPort;

  /// Newsgroup mapped to this list, or empty when unavailable.
  final String newsgroup;

  /// Base URL of the public-inbox mirror, or empty when unavailable.
  final String inboxBaseUrl;
}

/// Reports a catalogue that does not match the required schema.
final class CatalogException implements Exception {
  /// Creates an exception with a readable explanation.
  const CatalogException(this.message);

  /// Explanation of the schema violation.
  final String message;

  @override
  String toString() => 'invalid source catalogue: $message';
}

/// Loads the declarative source catalogue from YAML under `data/`.
final class CatalogLoader {
  /// Reads and validates the catalogue at [path].
  static List<ListSource> load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw CatalogException('source catalogue not found at $path');
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap || document['version'] != 1) {
      throw const CatalogException('unsupported source catalogue version');
    }
    final sources = document['sources'];
    if (sources is! YamlList) {
      throw const CatalogException('source catalogue has no sources list');
    }
    return sources.map(_parse).toList();
  }

  static ListSource _parse(Object? value) {
    if (value is! YamlMap) {
      throw const CatalogException('invalid source entry');
    }
    final id = _required(value, 'id');
    final listId = _required(value, 'list_id');
    final protocols = value['protocols'];
    if (protocols is! YamlMap) {
      throw CatalogException('source $id has no protocols');
    }
    final nntp = protocols['nntp'];
    final inbox = protocols['public_inbox'];
    return ListSource(
      id: id,
      label: value['label'] as String? ?? id,
      listId: listId,
      nntpHost: nntp is YamlMap ? nntp['host'] as String? ?? '' : '',
      nntpPort: nntp is YamlMap ? nntp['port'] as int? ?? 119 : 119,
      newsgroup: nntp is YamlMap ? nntp['newsgroup'] as String? ?? '' : '',
      inboxBaseUrl: inbox is YamlMap ? inbox['base_url'] as String? ?? '' : '',
    );
  }

  static String _required(YamlMap map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw CatalogException('missing required catalogue field $key');
    }
    return value;
  }
}
