// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('audit classifies residual, unmanaged and quarantined mail', () {
    final database = LocalDatabase.inMemory();
    addTearDown(database.close);
    database.setListPolicy('git@vger.kernel.org', 'move_to_ingested');
    database.quarantine(['q@example.invalid']);

    final report = AuditService(database: database).inspect([
      const InboxMessage(
        uid: '1',
        messageId: 'r@example.invalid',
        listId: 'git@vger.kernel.org',
      ),
      const InboxMessage(
        uid: '2',
        messageId: 'u@example.invalid',
        listId: 'other@example.invalid',
      ),
      const InboxMessage(
        uid: '3',
        messageId: 'q@example.invalid',
        listId: 'git@vger.kernel.org',
      ),
      const InboxMessage(uid: '4', messageId: 'personal@example.invalid'),
    ]);

    expect(report.residual.map((message) => message.uid), ['1']);
    expect(report.unmanaged.map((message) => message.uid), ['2']);
    expect(report.quarantined.map((message) => message.uid), ['3']);
  });

  test('audit does not change the profile', () {
    final database = LocalDatabase.inMemory();
    addTearDown(database.close);
    database.setListPolicy('git@vger.kernel.org', 'mark_seen');
    database.quarantine(['q@example.invalid']);
    final service = AuditService(database: database);

    service.inspect([
      const InboxMessage(
        uid: '1',
        messageId: 'r@example.invalid',
        listId: 'git@vger.kernel.org',
      ),
    ]);

    expect(database.rawPolicyOf('git@vger.kernel.org'), 'mark_seen');
    expect(database.quarantinedIds, ['q@example.invalid']);
  });

  test('an empty snapshot yields an empty report', () {
    final database = LocalDatabase.inMemory();
    addTearDown(database.close);

    final report = AuditService(database: database).inspect([]);

    expect(report.residual, isEmpty);
    expect(report.unmanaged, isEmpty);
    expect(report.quarantined, isEmpty);
  });

  test('audit runs through the real engine isolate', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-audit');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}profile.db';
    final setup = LocalDatabase.open(path);
    setup.setListPolicy('git@vger.kernel.org', 'move_to_ingested');
    setup.close();
    final client = await EngineClient.start();
    addTearDown(client.close);
    expect(
      await client.sendRequest(OpenProfileRequest('open', path)),
      isA<AckResponse>(),
    );

    final response = await client.sendRequest(
      AuditRequest('audit', [
        const InboxMessage(
          uid: '7',
          messageId: 'r@example.invalid',
          listId: 'git@vger.kernel.org',
        ),
      ]),
    );

    expect(response, isA<AuditResponse>());
    final audit = response as AuditResponse;
    expect(audit.residual, ['7']);
    expect(audit.unmanaged, isEmpty);
    expect(audit.quarantined, isEmpty);
  });

  test('audit requires an open profile', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(const AuditRequest('audit', []));

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'profile_not_open',
      ),
    );
  });
}
