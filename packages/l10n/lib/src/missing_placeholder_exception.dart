// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a message placeholder that has no supplied value.
final class MissingPlaceholderException implements Exception {
  /// Creates an exception for [name] in the message [key].
  const MissingPlaceholderException(this.key, this.name);

  /// Key of the message that contains the placeholder.
  final String key;

  /// Name of the placeholder with no argument.
  final String name;

  @override
  String toString() =>
      'MissingPlaceholderException: $name is missing from $key';
}
