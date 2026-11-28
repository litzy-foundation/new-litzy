// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

MessageData _message(String id) => MessageData(
  id: id,
  listId: 'git@vger.kernel.org',
  subject: 'subject $id',
  fromAddress: 'dev@example.invalid',
  dateEpoch: 1000,
  parentId: null,
  threadRootId: id,
  body: 'body $id',
  checksum: checksumOfBytes('body $id'.codeUnits),
);

Future<EngineClient> _openProfile(String path) async {
  final client = await EngineClient.start();
  final opened = await client.sendRequest(OpenProfileRequest('open', path));
  expect(opened, isA<AckResponse>());
  return client;
}

void main() {
  test('read and starred flags survive separate requests', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-triage');
    addTearDown(() => directory.deleteSync(recursive: true));
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);
    await client.sendRequest(
      IngestRequest('ingest', 'git@vger.kernel.org', [_message('m1')]),
    );

    final read = await client.sendRequest(
      const SetTriageRequest('r1', 'm1', TriageState.read, true),
    );
    final starred = await client.sendRequest(
      const SetTriageRequest('s1', 'm1', TriageState.starred, true),
    );
    final state = await client.sendRequest(const GetTriageRequest('g1', 'm1'));

    expect(
      read,
      isA<TriageResponse>().having((response) => response.read, 'read', isTrue),
    );
    expect(
      starred,
      isA<TriageResponse>().having(
        (response) => response.starred,
        'starred',
        isTrue,
      ),
    );
    expect(
      state,
      isA<TriageResponse>()
          .having((response) => response.read, 'read', isTrue)
          .having((response) => response.starred, 'starred', isTrue),
    );
  });

  test('a flag can be cleared explicitly', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-untriage');
    addTearDown(() => directory.deleteSync(recursive: true));
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);
    await client.sendRequest(
      IngestRequest('ingest', 'git@vger.kernel.org', [_message('m1')]),
    );
    await client.sendRequest(
      const SetTriageRequest('s1', 'm1', TriageState.starred, true),
    );

    final response = await client.sendRequest(
      const SetTriageRequest('s2', 'm1', TriageState.starred, false),
    );

    expect(
      response,
      isA<TriageResponse>().having(
        (value) => value.starred,
        'starred',
        isFalse,
      ),
    );
  });

  test('an unknown message is rejected', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-triage-miss');
    addTearDown(() => directory.deleteSync(recursive: true));
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);

    final response = await client.sendRequest(
      const SetTriageRequest('r1', 'absent', TriageState.read, true),
    );

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'message_not_found',
      ),
    );
  });

  test('triage before opening a profile returns a typed error', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const GetTriageRequest('g1', 'm1'),
    );

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'profile_not_open',
      ),
    );
  });

  test('triage flags are stored in SQLite', () {
    final database = LocalDatabase.inMemory();
    addTearDown(database.close);
    database.insertMessages([_record()]);

    database.setTriage('m1', read: true, starred: true);

    expect(database.triageOf('m1'), (read: true, starred: true));
  });
}

MessageRecord _record() => MessageRecord(
  id: 'm1',
  listId: 'git@vger.kernel.org',
  subject: 'subject m1',
  fromAddress: 'dev@example.invalid',
  dateEpoch: 1000,
  parentId: null,
  threadRootId: 'm1',
  body: 'body m1',
  checksum: checksumOfBytes('body m1'.codeUnits),
);
