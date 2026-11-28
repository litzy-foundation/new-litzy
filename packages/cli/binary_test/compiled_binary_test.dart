// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:engine/engine.dart';
import 'package:security/security.dart';
import 'package:test/test.dart';

import '../../engine/test/imap_fixture.dart';

Directory _litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains('- packages/cli')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('the Litzy root was not found');
    }
    directory = parent;
  }
}

String _fixture(Directory root, String name) => File(
  '${root.path}${Platform.pathSeparator}data${Platform.pathSeparator}'
  'fixtures${Platform.pathSeparator}$name',
).readAsStringSync();

Future<File> _compile(Directory root, Directory directory) async {
  final output = Directory('${directory.path}${Platform.pathSeparator}build');
  final result = await Process.run(Platform.resolvedExecutable, [
    'build',
    'cli',
    '-o',
    output.path,
    '-t',
    'packages/cli/bin/litzy.dart',
    '--root-package',
    'cli',
  ], workingDirectory: root.path);
  expect(result.exitCode, 0, reason: result.stderr as String);
  return File(
    '${output.path}${Platform.pathSeparator}bundle${Platform.pathSeparator}'
    'bin${Platform.pathSeparator}litzy',
  );
}

void _seedProfile(Directory directory, Directory root) {
  final defaults = DefaultCatalogue.resolve();
  final source = CatalogLoader.load(defaults.cataloguePath)
      .singleWhere((candidate) => candidate.id == defaults.sourceId);
  final channel = ChannelMapper.fromSource(source);
  final database = LocalDatabase.open(
    '${directory.path}${Platform.pathSeparator}litzy.db',
  );
  ListMessageIngestor(
    database: database,
    blobs: LocalBlobStore(
      Directory('${directory.path}${Platform.pathSeparator}blobs'),
    ),
  ).ingest(
    channel,
    LocalMailParser.parseMbox(_fixture(root, 'git_public_inbox_thread.mbox')),
  );
  database.close();
}

Map<String, Object?> _jsonObject(Object? text) =>
    jsonDecode(text! as String) as Map<String, Object?>;

List<Object?> _jsonList(Object? text, String key) =>
    _jsonObject(text)[key] as List<Object?>;

String _autoconfig(int imapPort) =>
    '''
<?xml version="1.0"?>
<clientConfig version="1.1">
  <emailProvider id="loopback.invalid">
    <incomingServer type="imap">
      <hostname>127.0.0.1</hostname>
      <port>$imapPort</port>
      <socketType>starttls</socketType>
      <authentication>password-cleartext</authentication>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>127.0.0.1</hostname>
      <port>465</port>
      <socketType>ssl</socketType>
      <authentication>password-cleartext</authentication>
    </outgoingServer>
  </emailProvider>
</clientConfig>
''';

String _fixturePolicy({required int httpPort, required int imapPort}) =>
    '''
version: 1
http_timeout_ms: 5000
max_document_bytes: 262144
redirect_budget: 2
dns_timeout_ms: 3000
allowed_imap_ports: [143, 993, $imapPort]
allowed_smtp_ports: [465, 587]
allow_loopback_plaintext_fixtures: true
default_list_id: git
loopback_fixture_http_port: $httpPort
''';

Future<ProcessResult> _run(
  File executable,
  Directory root,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.run(
  executable.path,
  arguments,
  workingDirectory: root.path,
  environment: environment,
);

void main() {
  test('the compiled CLI binary reads a real Git profile', () async {
    final root = _litzyRoot();
    final directory = Directory.systemTemp.createTempSync('litzy-cli-binary');
    addTearDown(() => directory.deleteSync(recursive: true));
    final executable = await _compile(root, directory);
    _seedProfile(directory, root);
    final database = '${directory.path}${Platform.pathSeparator}litzy.db';

    Future<ProcessResult> run(List<String> arguments) =>
        _run(executable, root, ['--database', database, ...arguments]);

    final channels = await run(['channels']);
    final listed = await run(['list']);
    final shown = await run(['show', 'm1@example.invalid']);

    expect(channels.exitCode, 0, reason: channels.stderr as String);
    expect(listed.exitCode, 0, reason: listed.stderr as String);
    expect(shown.exitCode, 0, reason: shown.stderr as String);
    final channel =
        _jsonList(channels.stdout, 'channels').single as Map<String, Object?>;
    expect(channel['listId'], 'git@vger.kernel.org');
    final summary =
        _jsonList(listed.stdout, 'threads').single as Map<String, Object?>;
    expect(summary['messageCount'], 2);
    final messages = _jsonList(shown.stdout, 'messages');
    expect(messages, hasLength(2));
  });

  test('the compiled CLI binary connects an account from an address', () async {
    final root = _litzyRoot();
    final directory = Directory.systemTemp.createTempSync('litzy-cli-access');
    addTearDown(() => directory.deleteSync(recursive: true));
    final executable = await _compile(root, directory);
    final password =
        'probe${DateTime.now().microsecondsSinceEpoch}'
        '${Random.secure().nextInt(1 << 30)}';
    final fixture = ImapFixture(messages: const [], expectedPassword: password);
    await fixture.start();
    addTearDown(fixture.close);
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) {
      request.response.headers.contentType = ContentType(
        'application',
        'xml',
        charset: 'utf-8',
      );
      request.response.write(_autoconfig(fixture.port));
      unawaited(request.response.close());
    });
    addTearDown(http.close);
    final policy = File('${directory.path}${Platform.pathSeparator}policy.yaml')
      ..writeAsStringSync(
        _fixturePolicy(httpPort: http.port, imapPort: fixture.port),
      );
    final environment = Map<String, String>.from(Platform.environment);
    environment[AccessPolicyEnvironmentKeys.policyPath] = policy.path;
    final database = '${directory.path}${Platform.pathSeparator}litzy.db';
    final keychain = LibsecretStore();
    const key = 'password.127.0.0.1.user@127.0.0.1';
    addTearDown(() => keychain.remove(key));

    final discovered = await _run(executable, root, [
      'discover',
      'user@127.0.0.1',
    ], environment: environment);
    expect(discovered.exitCode, 0, reason: discovered.stderr as String);
    final account = _jsonObject(discovered.stdout);
    expect(account['email'], 'user@127.0.0.1');
    expect((account['imap']! as Map<String, Object?>)['port'], fixture.port);

    Future<({int code, String output, String error})> connect(
      String secret,
    ) async {
      final process = await Process.start(
        executable.path,
        ['--database', database, 'connect', 'user@127.0.0.1'],
        workingDirectory: root.path,
        environment: environment,
      );
      final outputBuffer = StringBuffer();
      final errorBuffer = StringBuffer();
      process.stdout.transform(utf8.decoder).listen(outputBuffer.write);
      process.stderr.transform(utf8.decoder).listen(errorBuffer.write);
      process.stdin.writeln(secret);
      await process.stdin.close();
      final code = await process.exitCode;
      return (
        code: code,
        output: outputBuffer.toString(),
        error: errorBuffer.toString(),
      );
    }

    final successful = await connect(password);
    expect(successful.code, 0, reason: successful.error);
    final connected = _jsonObject(successful.output);
    expect(connected['email'], 'user@127.0.0.1');
    expect(await keychain.get(key), password);
    expect(fixture.rejectedLogins, 0);
    expect(fixture.actions, contains('LOGIN'));
    expect(fixture.actions.join(' '), isNot(contains(password)));
    expect(successful.error, isNot(contains(password)));

    final accounts = await _run(executable, root, [
      '--database',
      database,
      'accounts',
    ], environment: environment);
    expect(accounts.exitCode, 0, reason: accounts.stderr as String);
    final stored =
        _jsonList(accounts.stdout, 'accounts').single as Map<String, Object?>;
    expect(stored['email'], 'user@127.0.0.1');
    expect(stored['imapPort'], fixture.port);
    expect(stored['listId'], 'git');

    final rejectedPassword = '$password-rejected';
    final rejected = await connect(rejectedPassword);
    expect(rejected.code, 1);
    expect(rejected.error, contains('authentication_failed'));
    expect(await keychain.get(key), isNull);
    expect(fixture.rejectedLogins, 1);
    expect(rejected.error, isNot(contains(rejectedPassword)));
  });
}
