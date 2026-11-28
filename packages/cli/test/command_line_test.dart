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

  test('reply takes a message identifier and a body', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'reply',
      'm1@example.invalid',
      '--body',
      'my reply',
    ]);

    final command = parsed.command as ReplyCommand;
    expect(command.messageId, 'm1@example.invalid');
    expect(command.body, 'my reply');
  });

  test('reply needs a body', () {
    expect(
      () => parseCommandLine([
        '--database',
        'p.db',
        'reply',
        'm1@example.invalid',
      ]),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('import takes a local path and a format', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'import',
      '--format',
      'maildir',
      'Maildir',
    ]);

    final command = parsed.command as ImportCommand;
    expect(command.path, 'Maildir');
    expect(command.format, MailImportFormat.maildir);
  });

  test('import needs a known format', () {
    expect(
      () => parseCommandLine(['--database', 'p.db', 'import', 'inbox.mbox']),
      throwsA(isA<CliUsageException>()),
    );
    expect(
      () => parseCommandLine([
        '--database',
        'p.db',
        'import',
        '--format',
        'pst',
        'inbox.pst',
      ]),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('triage sets read and starred flags on one message', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'triage',
      'm1@example.invalid',
      '--read',
      '--star',
    ]);

    final command = parsed.command as TriageCommand;
    expect(command.messageId, 'm1@example.invalid');
    expect(command.read, isTrue);
    expect(command.starred, isTrue);
  });

  test('a flag can be cleared', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'triage',
      'm1@example.invalid',
      '--unstar',
    ]);

    expect((parsed.command as TriageCommand).starred, isFalse);
  });

  test('conflicting triage flags are rejected', () {
    expect(
      () => parseCommandLine([
        '--database',
        'p.db',
        'triage',
        'm1',
        '--read',
        '--unread',
      ]),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('triage needs at least one flag', () {
    expect(
      () => parseCommandLine(['--database', 'p.db', 'triage', 'm1']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('audit reads a snapshot from a file', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'audit',
      '--snapshot',
      'inbox.json',
    ]);

    expect((parsed.command as AuditCommand).snapshotPath, 'inbox.json');
  });

  test('audit requires a snapshot path', () {
    expect(
      () => parseCommandLine(['--database', 'p.db', 'audit']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('data verbs require a database path', () {
    expect(
      () => parseCommandLine(['search', 'terms']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('sync can use the default catalogue and source', () {
    final parsed = parseCommandLine(['--database', 'p.db', 'sync']);
    final command = parsed.command as SyncCommand;

    expect(command.cataloguePath, isNull);
    expect(command.sourceId, isNull);
  });

  test('sync accepts an explicit source with the default catalogue', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'sync',
      '--source',
      'git',
    ]);
    final command = parsed.command as SyncCommand;

    expect(command.cataloguePath, isNull);
    expect(command.sourceId, 'git');
  });

  test('channels, list and show are parsed as reading commands', () {
    final channels = parseCommandLine(['--database', 'p.db', 'channels']);
    final listed = parseCommandLine(['--database', 'p.db', 'list', 'git']);
    final shown = parseCommandLine([
      '--database',
      'p.db',
      'show',
      'm1@example.invalid',
    ]);

    expect(channels.command, isA<ChannelsCommand>());
    expect((listed.command as ListCommand).channelId, 'git');
    expect((shown.command as ShowCommand).rootId, 'm1@example.invalid');
  });

  test('show needs a thread root', () {
    expect(
      () => parseCommandLine(['--database', 'p.db', 'show']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('discover needs only an email address', () {
    final parsed = parseCommandLine(['discover', 'user@example.com']);

    expect(parsed.databasePath, isNull);
    expect(
      (parsed.command as DiscoverCommand).emailAddress,
      'user@example.com',
    );
  });

  test('connect needs an email address and accepts a database', () {
    final parsed = parseCommandLine([
      '--database',
      'p.db',
      'connect',
      'user@example.com',
    ]);

    expect(parsed.databasePath, 'p.db');
    expect((parsed.command as ConnectCommand).emailAddress, 'user@example.com');
  });

  test('the connect command never accepts a password option', () {
    expect(
      () => parseCommandLine([
        '--database',
        'p.db',
        'connect',
        'user@example.com',
        '--password',
        'secret',
      ]),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('accounts takes no argument', () {
    final parsed = parseCommandLine(['--database', 'p.db', 'accounts']);
    expect(parsed.command, isA<AccountsCommand>());
    expect(
      () => parseCommandLine(['--database', 'p.db', 'accounts', 'extra']),
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
