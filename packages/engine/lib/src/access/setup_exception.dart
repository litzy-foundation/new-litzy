// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a deterministic failure during account connection.
library;

/// An account connection failure with a stable code safe for a message key.
final class SetupException implements Exception {
  /// Creates a failure with [code] and a readable [message].
  const SetupException(this.code, this.message);

  /// Stable failure code such as `authentication_failed`.
  final String code;

  /// Explanation that never contains credential material.
  final String message;

  @override
  String toString() => 'account setup failed ($code): $message';
}
