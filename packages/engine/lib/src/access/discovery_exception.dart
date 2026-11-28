// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a deterministic failure during automatic mail discovery.
library;

/// A discovery failure with a stable code safe for a localized message key.
final class DiscoveryException implements Exception {
  /// Creates a failure with [code] and a readable [message].
  const DiscoveryException(this.code, this.message);

  /// Stable failure code such as `invalid_email` or `insecure_transport`.
  final String code;

  /// Explanation that never contains a credential.
  final String message;

  @override
  String toString() => 'discovery failed ($code): $message';
}
