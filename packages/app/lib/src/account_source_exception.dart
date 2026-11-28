// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Typed failure returned by the GUI account port.
library;

/// Failed account setup with a stable machine-readable code.
final class AccountSourceException implements Exception {
  /// Creates a failure with [code] and a localized [message].
  const AccountSourceException(this.code, this.message);

  /// Deterministic code returned by the engine.
  final String code;

  /// Explanation safe to show in the interface.
  final String message;

  @override
  String toString() => 'account source failed ($code): $message';
}
