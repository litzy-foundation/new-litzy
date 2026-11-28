// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Deterministic failure returned by a reading source.
final class ReadingFailure implements Exception {
  /// Creates a failure with the stable [code] reported by the engine.
  const ReadingFailure(this.code);

  /// Stable code that selects the localized message.
  final String code;

  @override
  String toString() => 'ReadingFailure: $code';
}
