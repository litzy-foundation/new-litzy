// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a Fluent resource line that cannot be parsed.
final class FluentParseException implements Exception {
  /// Creates an exception for the offending [line] with a readable [message].
  const FluentParseException(this.line, this.message);

  /// Source line that could not be parsed.
  final String line;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'FluentParseException: $message in "$line"';
}
