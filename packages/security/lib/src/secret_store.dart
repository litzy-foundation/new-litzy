// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a failure of the operating system keychain.
final class SecretStoreException implements Exception {
  /// Creates an exception with a readable [message].
  const SecretStoreException(this.message);

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'secret store failed: $message';
}

/// Platform port for secret storage.
///
/// An implementation uses `flutter_secure_storage` on mobile and libsecret or
/// the native equivalent on desktop, as required by R35 and ADR-0007. The
/// port keeps credentials out of SQLite, versioned files and logs. Tests
/// replace it with an in-memory fake so no real secret material is needed.
abstract interface class SecretStore {
  /// Stores [secret] under [key], replacing any previous value.
  Future<void> put(String key, String secret);

  /// Returns the secret under [key], or null when absent.
  Future<String?> get(String key);

  /// Removes the secret under [key].
  Future<void> remove(String key);
}
