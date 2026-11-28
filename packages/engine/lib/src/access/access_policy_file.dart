// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Locates the declarative access policy beside the engine package.
///
/// The search covers source runs, package tests and compiled clients launched
/// from the workspace root, as required by R2 and ADR-0025.
library;

import 'dart:io';

import 'access_policy.dart';

/// Reads the versioned access policy from `data/access`.
final class AccessPolicyFile {
  const AccessPolicyFile._();

  /// Repository-relative location of the policy.
  static const String relativeLocation = 'data/access/policy.yaml';

  /// Reads and parses the policy, failing explicitly when it is missing.
  static AccessPolicy read() {
    final file = _locate();
    return AccessPolicy.fromYaml(file.readAsStringSync());
  }

  static File _locate() {
    final candidates = <File>[
      File.fromUri(Platform.script.resolve(relativeLocation)),
      File.fromUri(Platform.script.resolve('../$relativeLocation')),
      File.fromUri(Platform.script.resolve('../../$relativeLocation')),
      File(relativeLocation),
      File('../$relativeLocation'),
      File('../../$relativeLocation'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate;
    }
    throw StateError('the access policy is missing');
  }
}
