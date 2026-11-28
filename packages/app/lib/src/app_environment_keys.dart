// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Environment keys used only for binary acceptance and local profile
/// injection.
///
/// These values are identifiers, not secrets. The normal client ignores them
/// and resolves its profile through the platform support directory.
library;

/// Names of environment variables understood by the client entry point.
final class AppEnvironmentKeys {
  const AppEnvironmentKeys._();

  /// Overrides the profile path with a path owned by an acceptance harness.
  static const String profilePath = 'LITZY_PROFILE_PATH';

  /// Enables machine-readable acceptance output.
  static const String acceptance = 'LITZY_ACCEPTANCE';

  /// Value that enables acceptance output.
  static const String enabled = '1';
}
