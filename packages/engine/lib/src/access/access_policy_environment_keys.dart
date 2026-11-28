// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Environment identifier used to point the engine at a fixture policy.
///
/// The value is a path, not a secret. Binary acceptance uses it to select a
/// declarative policy with loopback fixture ports while the shipped client
/// keeps reading the versioned file.
library;

/// Names of environment variables understood by the policy locator.
final class AccessPolicyEnvironmentKeys {
  const AccessPolicyEnvironmentKeys._();

  /// Replaces the policy path with a file owned by an acceptance harness.
  static const String policyPath = 'LITZY_ACCESS_POLICY';
}
