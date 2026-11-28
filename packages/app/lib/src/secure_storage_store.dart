// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// GUI keychain adapter backed by `flutter_secure_storage`.
///
/// R35 and R55 require credentials in the operating system keychain on every
/// target. The plugin maps to Keychain on iOS and macOS, Keystore on Android,
/// Credential Manager on Windows and libsecret on Linux. No secret is written
/// to SQLite, a versioned file or a log by this adapter.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:security/security.dart';

/// Stores secrets through the platform secure storage plugin.
final class FlutterSecureStorageStore implements SecretStore {
  /// Creates an adapter over an injected plugin for deterministic tests.
  const FlutterSecureStorageStore({this.storage});

  /// Plugin used for keychain access, or a fresh one when absent.
  final FlutterSecureStorage? storage;

  FlutterSecureStorage get _storage => storage ?? const FlutterSecureStorage();

  @override
  Future<void> put(String key, String secret) =>
      _storage.write(key: key, value: secret);

  @override
  Future<String?> get(String key) => _storage.read(key: key);

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}
