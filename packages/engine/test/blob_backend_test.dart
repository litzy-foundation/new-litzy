// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';

final class _Harness {
  _Harness() {
    directory = Directory.systemTemp.createTempSync('litzy-blob-backend');
    database = LocalDatabase.open(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
  }

  late final Directory directory;
  late final LocalDatabase database;

  BlobStore store(BlobBackend backend) => switch (backend) {
    BlobBackend.folder => LocalBlobStore(
      Directory('${directory.path}${Platform.pathSeparator}blobs'),
    ),
    BlobBackend.sqlite => SqliteBlobStore(database),
  };

  Database openRawProfile() =>
      sqlite3.open('${directory.path}${Platform.pathSeparator}profile.db');

  File backup() => File('${directory.path}${Platform.pathSeparator}backup.db');

  void close() {
    database.close();
    directory.deleteSync(recursive: true);
  }
}

void main() {
  final raw = Uint8List.fromList(utf8.encode('a cover letter' * 400));
  final digest = checksumOfBytes(raw);

  for (final backend in BlobBackend.values) {
    test('$backend stores and reads bytes through the port', () {
      final harness = _Harness();
      addTearDown(harness.close);
      final store = harness.store(backend);

      final stored = store.put(raw);

      expect(stored, digest);
      expect(store.get(digest), raw);
      expect(store.verify(digest), isTrue);
    });

    test('$backend deduplicates a repeated digest', () {
      final harness = _Harness();
      addTearDown(harness.close);
      final store = harness.store(backend);

      expect(store.put(raw), digest);
      expect(store.put(raw), digest);
    });

    test('$backend answers an absent digest without throwing', () {
      final harness = _Harness();
      addTearDown(harness.close);
      final store = harness.store(backend);

      expect(store.get('absent'), isNull);
      expect(store.verify('absent'), isFalse);
    });
  }

  test('the folder backend rejects a file whose bytes were replaced', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store(BlobBackend.folder);
    store.put(raw);
    final file = File(
      '${harness.directory.path}${Platform.pathSeparator}blobs'
      '${Platform.pathSeparator}$digest',
    );

    file.writeAsBytesSync(utf8.encode('different content'));

    expect(store.get(digest), isNull);
    expect(store.verify(digest), isFalse);
  });

  test(
    'the SQLite backend stores a compressed frame with its codec and size',
    () {
      final harness = _Harness();
      addTearDown(harness.close);
      final store = harness.store(BlobBackend.sqlite);

      store.put(raw);
      store.put(raw);
      final rawProfile = harness.openRawProfile();
      addTearDown(rawProfile.dispose);
      final rows = rawProfile.select(
        'SELECT codec, size, length(payload) AS stored FROM blobs WHERE digest = ?',
        [digest],
      );

      expect(rows, hasLength(1));
      expect(rows.single['codec'], 'zstd');
      expect(rows.single['size'], raw.length);
      expect(rows.single['stored'], lessThan(raw.length));
    },
  );

  test('the SQLite backend rejects a corrupt compressed frame', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store(BlobBackend.sqlite);
    store.put(raw);
    final rawProfile = harness.openRawProfile();
    addTearDown(rawProfile.dispose);

    rawProfile.execute('UPDATE blobs SET payload = ? WHERE digest = ?', [
      Uint8List.fromList([1, 2, 3, 4]),
      digest,
    ]);

    expect(store.get(digest), isNull);
    expect(store.verify(digest), isFalse);
  });

  test('the SQLite backend rejects a frame with a mismatched size', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store(BlobBackend.sqlite);
    store.put(raw);
    final rawProfile = harness.openRawProfile();
    addTearDown(rawProfile.dispose);

    rawProfile.execute('UPDATE blobs SET size = ? WHERE digest = ?', [
      raw.length + 1,
      digest,
    ]);

    expect(store.get(digest), isNull);
  });

  test('the SQLite backend rejects an unknown codec', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store(BlobBackend.sqlite);
    store.put(raw);
    final rawProfile = harness.openRawProfile();
    addTearDown(rawProfile.dispose);

    rawProfile.execute("UPDATE blobs SET codec = 'unknown' WHERE digest = ?", [
      digest,
    ]);

    expect(store.get(digest), isNull);
  });

  test('the SQLite backend bounds an implausible recorded size', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store(BlobBackend.sqlite);
    store.put(raw);
    final rawProfile = harness.openRawProfile();
    addTearDown(rawProfile.dispose);

    rawProfile.execute('UPDATE blobs SET size = ? WHERE digest = ?', [
      1 << 40,
      digest,
    ]);

    expect(store.get(digest), isNull);
  });

  test('a profile backup contains the compressed content', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store(BlobBackend.sqlite);
    store.put(raw);

    harness.database.backupTo(harness.backup());
    final restored = LocalDatabase.open(harness.backup().path);
    addTearDown(restored.close);

    expect(SqliteBlobStore(restored).get(digest), raw);
  });

  test(
    'the open verb selects the SQLite backend without a blob folder',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'litzy-open-sqlite',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final client = await EngineClient.start();
      addTearDown(client.close);

      final response = await client.sendRequest(
        OpenProfileRequest(
          'o1',
          '${directory.path}${Platform.pathSeparator}profile.db',
          blobBackend: BlobBackend.sqlite,
        ),
      );

      expect(response, isA<AckResponse>());
      expect(
        Directory('${directory.path}${Platform.pathSeparator}blobs')
            .existsSync(),
        isFalse,
      );
    },
  );
}
