// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a request for a message key that is absent from the resource.
final class MissingMessageException implements Exception {
  /// Creates an exception for the absent [key].
  const MissingMessageException(this.key);

  /// Key that was requested.
  final String key;

  @override
  String toString() => 'MissingMessageException: $key';
}
