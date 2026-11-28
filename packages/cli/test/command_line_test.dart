// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:test/test.dart';
import 'package:protocol/protocol.dart';
import 'package:cli/cli.dart';

void main() {
  test('ping does not require a profile', () {
    final parsed = parseCommandLine(['ping']);

    expect(parsed.databasePath, isNull);
    expect(parsed.command, isA<PingCommand>());
  });

  test('a database path and a sync source are parsed', () {
    final parsed = parseCommandLine([
      '--database',
      'profile.db',
      '--blobs',
      'blobs',
      'sync',
      '--catalogue',
      'lists.yaml',
      '--source',
      'git',
    ]);

    expect(parsed.databasePath, 'profile.db');
    expect(parsed.blobsDirectory, 'blobs');
    final command = parsed.command as SyncCommand;
    expect(command.cataloguePath, 'lists.yaml');
    expect(command.sourceId, 'git');
  });

  test('search and thread take one argument each', () {
    final search = parseCommandLine([
      '--database',
      'p.db',
      'search',
      'two words',
    ]);
    final thread = parseCommandLine([
      '--database',
      'p.db',
      'thread',
      'm1@example.invalid',
    ]);

    expect((search.command as SearchCommand).terms, 'two words');
    expect((thread.command as ThreadCommand).rootId, 'm1@example.invalid');
  });

  test('the SQLite blob backend is selected by an option', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      '--blob-backend',
      'sqlite',
      'search',
      'terms',
    ]);

    expect(parsed.blobBackend, BlobBackend.sqlite);
  });

  test('an unknown blob backend is rejected', () {
    expect(
      () => parseCommandLine([
        '--database',
        'p.db',
        '--blob-backend',
        'object-store',
        'search',
        'terms',
      ]),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('data verbs require a database path', () {
    expect(
      () => parseCommandLine(['search', 'terms']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('sync requires a catalogue and a source', () {
    expect(
      () => parseCommandLine([
        '--database',
        'p.db',
        'sync',
        '--catalogue',
        'lists.yaml',
      ]),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('an unknown command is rejected', () {
    expect(
      () => parseCommandLine(['--database', 'p.db', 'delete-everything']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('an option without a value is rejected', () {
    expect(
      () => parseCommandLine(['--database']),
      throwsA(isA<CliUsageException>()),
    );
  });
}
