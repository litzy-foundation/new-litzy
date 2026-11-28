// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'package:engine/engine.dart';

final class _Harness {
  _Harness() {
    directory = Directory.systemTemp.createTempSync('litzy-blob-store');
    databasePath = '${directory.path}${Platform.pathSeparator}profile.db';
    database = LocalDatabase.open(databasePath);
  }

  late final Directory directory;
  late final String databasePath;
  late final LocalDatabase database;

  LocalBlobStore get store => LocalBlobStore(
    Directory('${directory.path}${Platform.pathSeparator}blobs'),
  );

  Database openRawProfile() => sqlite3.open(databasePath);

  void close() {
    database.close();
    directory.deleteSync(recursive: true);
  }
}

Directory _engineRoot() {
  var directory = Directory.current;
  while (true) {
    final pubspec = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: engine')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('the engine package was not found');
}

({Future<int> code, Future<String> error}) watchWorker(Process process) {
  final error = StringBuffer();
  process.stdout.transform(utf8.decoder).listen((_) {});
  final errorDone = process.stderr
      .transform(utf8.decoder)
      .listen(error.write)
      .asFuture<void>();
  final code = process.exitCode.then((value) async {
    await errorDone;
    return value;
  });
  return (code: code, error: errorDone.then((_) => error.toString()));
}

Future<void> _waitForReadyFiles(List<File> files) async {
  for (var attempt = 0; attempt < 3000; attempt++) {
    if (files.every((file) => file.existsSync())) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('the workers did not open the profile');
}

Map<String, Object?> legacyFixture() {
  final workspace = _engineRoot().parent.parent.path;
  final file = File(
    '$workspace${Platform.pathSeparator}data${Platform.pathSeparator}fixtures'
    '${Platform.pathSeparator}legacy_zstd_blob.yaml',
  );
  final loaded = loadYaml(file.readAsStringSync()) as YamlMap;
  return <String, Object?>{
    'codec': loaded['codec'] as String,
    'size': loaded['size'] as int,
    'digest': loaded['digest'] as String,
    'payload': base64.decode(loaded['payload_base64'] as String),
  };
}

void main() {
  final raw = Uint8List.fromList(utf8.encode('a cover letter' * 400));
  final digest = checksumOfBytes(raw);

  test('the store writes a compressed file below the digest prefixes', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store;

    expect(store.put(raw), digest);
    expect(store.get(digest), raw);
    expect(store.verify(digest), isTrue);

    final file = File(
      '${harness.directory.path}${Platform.pathSeparator}blobs'
      '${Platform.pathSeparator}${digest.substring(0, 2)}'
      '${Platform.pathSeparator}${digest.substring(2, 4)}'
      '${Platform.pathSeparator}$digest.eml.gz',
    );
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), lessThan(raw.length));
  });

  test('a repeated digest is stored once', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store;

    expect(store.put(raw), digest);
    expect(store.put(raw), digest);
  });

  test('an absent digest is reported without throwing', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store;

    expect(store.get('absent'), isNull);
    expect(store.verify('absent'), isFalse);
  });

  test('a corrupt compressed file is not returned', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final store = harness.store;
    store.put(raw);
    final file = File(
      '${harness.directory.path}${Platform.pathSeparator}blobs'
      '${Platform.pathSeparator}${digest.substring(0, 2)}'
      '${Platform.pathSeparator}${digest.substring(2, 4)}'
      '${Platform.pathSeparator}$digest.eml.gz',
    );

    file.writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));

    expect(store.get(digest), isNull);
    expect(store.verify(digest), isFalse);
  });

  test('a flat uncompressed file is copied into the new layout', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final legacy = File(
      '${harness.directory.path}${Platform.pathSeparator}blobs'
      '${Platform.pathSeparator}$digest',
    );
    legacy.parent.createSync(recursive: true);
    legacy.writeAsBytesSync(raw);

    expect(harness.store.get(digest), raw);
    expect(harness.store.verify(digest), isTrue);
    expect(legacy.existsSync(), isTrue);
  });

  test('every open sets WAL and a five second busy timeout', () {
    final harness = _Harness();
    addTearDown(harness.close);

    expect(harness.database.journalMode.toLowerCase(), 'wal');
    expect(
      harness.database.busyTimeoutMilliseconds,
      SqliteSettings.busyTimeoutMilliseconds,
    );
  });

  test('a legacy SQLite row migrates byte for byte', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final fixture = legacyFixture();
    final rawDatabase = harness.openRawProfile();
    rawDatabase.execute(SqlResources.statement(SqlKeys.createLegacyBlobs));
    rawDatabase.execute(SqlResources.statement(SqlKeys.insertLegacyBlob), [
      fixture['digest'],
      fixture['codec'],
      fixture['size'],
      fixture['payload'],
    ]);
    rawDatabase.dispose();

    final reopened = LocalDatabase.open(harness.databasePath);
    addTearDown(reopened.close);
    final store = harness.store;
    final migrated = LegacyBlobMigrator(reopened, store).migrate();

    expect(migrated, 1);
    expect(
      store.get(fixture['digest'] as String),
      utf8.encode('legacy message body' * 12),
    );
    expect(reopened.hasLegacyBlobs(), isFalse);
  });

  test('a corrupt legacy row keeps the table for later recovery', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final fixture = legacyFixture();
    final rawDatabase = harness.openRawProfile();
    rawDatabase.execute(SqlResources.statement(SqlKeys.createLegacyBlobs));
    rawDatabase.execute(SqlResources.statement(SqlKeys.insertLegacyBlob), [
      fixture['digest'],
      fixture['codec'],
      fixture['size'],
      Uint8List.fromList([1, 2, 3, 4]),
    ]);
    rawDatabase.dispose();

    final reopened = LocalDatabase.open(harness.databasePath);
    addTearDown(reopened.close);
    final migrated = LegacyBlobMigrator(reopened, harness.store).migrate();

    expect(migrated, 0);
    expect(reopened.hasLegacyBlobs(), isTrue);
  });

  test(
    'two processes can write to one profile without a lock service',
    timeout: const Timeout(Duration(seconds: 90)),
    () async {
      final harness = _Harness();
      addTearDown(harness.close);
      final worker =
          '${_engineRoot().path}${Platform.pathSeparator}test'
          '${Platform.pathSeparator}profile_worker.dart';
      final marker = File(
        '${harness.directory.path}${Platform.pathSeparator}worker.marker',
      );
      final readyFiles = [
        for (final id in ['first', 'second'])
          File('${harness.directory.path}${Platform.pathSeparator}$id.ready'),
      ];
      final processes = [
        for (final index in [0, 1])
          await Process.start(Platform.resolvedExecutable, [
            worker,
            harness.databasePath,
            '<${index == 0 ? 'first' : 'second'}@example.invalid>',
            readyFiles[index].path,
            marker.path,
          ], workingDirectory: Directory.current.path),
      ];
      addTearDown(
        () => Future.wait(processes.map((process) => process.exitCode)),
      );
      final watchers = [for (final process in processes) watchWorker(process)];

      await _waitForReadyFiles(readyFiles)
          .timeout(const Duration(seconds: 35))
          .catchError((Object error) async {
            final codes = await Future.wait(
              watchers.map((watcher) => watcher.code),
            );
            final errors = await Future.wait(
              watchers.map((watcher) => watcher.error),
            );
            throw StateError('$error; codes=$codes; ${errors.join()}');
          });
      marker.writeAsStringSync('go');

      final codes = await Future.wait(watchers.map((watcher) => watcher.code));
      final errors = await Future.wait(
        watchers.map((watcher) => watcher.error),
      );
      expect(codes, [0, 0], reason: errors.join());
      expect(harness.database.messageIds, [
        '<first@example.invalid>',
        '<second@example.invalid>',
      ]);
    },
  );
}
