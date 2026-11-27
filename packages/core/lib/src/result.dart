// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// A deterministic outcome that either carries a value or a typed failure.
sealed class Result<T> {
  /// Creates a result.
  const Result();

  /// Whether the result carries a value.
  bool get isOk => switch (this) {
    Ok<T>() => true,
    Err<T>() => false,
  };
}

/// A successful result carrying [value].
final class Ok<T> extends Result<T> {
  /// Creates a successful result.
  const Ok(this.value);

  /// The produced value.
  final T value;
}

/// A failed result carrying a stable [code] and a readable [message].
final class Err<T> extends Result<T> {
  /// Creates a failed result.
  const Err(this.code, this.message);

  /// Stable machine-readable code.
  final String code;

  /// Human-readable explanation of the failure.
  final String message;
}
