// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a declarative client setting that is missing or malformed.
final class ConfigurationException implements Exception {
  /// Creates an exception explaining the invalid [field].
  const ConfigurationException(this.field, this.message);

  /// Name of the invalid field.
  final String field;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'ConfigurationException: $field $message';
}
