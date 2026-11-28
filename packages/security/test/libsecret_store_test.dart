// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:security/security.dart';
import 'package:test/test.dart';

void main() {
  test('the libsecret adapter round-trips and removes a probe value', () async {
    final store = LibsecretStore();
    final key = 'litzy.test.${DateTime.now().microsecondsSinceEpoch}';
    const probe = 'keychain-round-trip-probe';
    try {
      await store.put(key, probe);
      expect(await store.get(key), probe);
      await store.remove(key);
      expect(await store.get(key), isNull);
    } finally {
      await store.remove(key);
    }
  });
}
