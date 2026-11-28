// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:test/test.dart';
import 'package:engine/engine.dart';

final class _MailboxFailure implements MailboxException {
  const _MailboxFailure(this.code, this.message);

  @override
  final String code;

  @override
  final String message;
}

final class FakeMailbox implements MailboxPort {
  final List<String> calls = <String>[];

  bool failNext = false;

  bool failTypedNext = false;

  @override
  Future<void> moveToFolder(List<String> uids, String folder) async {
    if (failTypedNext) {
      failTypedNext = false;
      throw const _MailboxFailure('unavailable', 'the folder is unavailable');
    }
    if (failNext) {
      failNext = false;
      throw StateError('folder is unavailable');
    }
    calls.add('move:$folder:${uids.join(',')}');
  }

  @override
  Future<void> markSeen(List<String> uids) async {
    calls.add('seen:${uids.join(',')}');
  }

  @override
  Future<void> expunge(List<String> uids) async {
    calls.add('expunge:${uids.join(',')}');
  }
}

final class _Harness {
  _Harness() {
    directory = Directory.systemTemp.createTempSync('litzy-purge');
    database = LocalDatabase.inMemory();
    blobs = LocalBlobStore(directory);
    mailbox = FakeMailbox();
    coordinator = PurgeCoordinator(
      database: database,
      blobs: blobs,
      mailbox: mailbox,
    );
  }

  late final Directory directory;
  late final LocalDatabase database;
  late final LocalBlobStore blobs;
  late final FakeMailbox mailbox;
  late final PurgeCoordinator coordinator;

  void close() {
    database.close();
    directory.deleteSync(recursive: true);
  }
}

PurgeCandidate _store(_Harness harness, String id, String uid) {
  final bytes = 'raw:$id'.codeUnits;
  final checksum = harness.blobs.put(bytes);
  harness.database.insertMessages([
    MessageRecord(
      id: id,
      listId: 'git@vger.kernel.org',
      subject: 'subject',
      fromAddress: 'dev@example.invalid',
      dateEpoch: 1,
      parentId: null,
      threadRootId: id,
      body: String.fromCharCodes(bytes),
      checksum: checksum,
    ),
  ]);
  return PurgeCandidate(uid: uid, messageId: id, checksum: checksum);
}

void main() {
  test('the default policy moves messages and never expunges', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');

    final plan = await harness.coordinator.prepare(
      'd1',
      'git@vger.kernel.org',
      [candidate],
    );
    final outcome = await harness.coordinator.commit(plan);

    expect(outcome, isA<PurgeApplied>());
    expect(harness.mailbox.calls, ['move:Litzy/Ingested:1']);
  });

  test('the mark-seen policy archives without expunging', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    harness.database.setListPolicy(
      'git@vger.kernel.org',
      MailboxAction.markSeen.storageName,
    );

    final plan = await harness.coordinator.prepare(
      'd2',
      'git@vger.kernel.org',
      [candidate],
    );
    await harness.coordinator.commit(plan);

    expect(harness.mailbox.calls, ['seen:1']);
  });

  test('an explicit list opt-in expunges only after verification', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    harness.database.setListPolicy(
      'git@vger.kernel.org',
      MailboxAction.expunge.storageName,
    );

    final plan = await harness.coordinator.prepare(
      'd3',
      'git@vger.kernel.org',
      [candidate],
    );
    final outcome = await harness.coordinator.commit(plan);

    expect((outcome as PurgeApplied).action, 'expunge');
    expect(harness.mailbox.calls, ['expunge:1']);
  });

  test('an unverified candidate is quarantined and never deleted', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final good = _store(harness, 'm1', '1');
    const bad = PurgeCandidate(
      uid: '2',
      messageId: 'missing',
      checksum: 'deadbeef',
    );

    final plan = await harness.coordinator.prepare(
      'd4',
      'git@vger.kernel.org',
      [good, bad],
    );

    expect(plan.quarantined.map((candidate) => candidate.messageId), [
      'missing',
    ]);
    expect(harness.database.quarantinedIds, contains('missing'));
    await harness.coordinator.commit(plan);
    expect(harness.mailbox.calls, ['move:Litzy/Ingested:1']);
  });

  test('an altered preparation fails the digest gate', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    final plan = await harness.coordinator.prepare(
      'd5',
      'git@vger.kernel.org',
      [candidate],
    );
    final altered = PreparedPurge(
      id: plan.id,
      listId: plan.listId,
      accepted: [
        PurgeCandidate(
          uid: candidate.uid,
          messageId: candidate.messageId,
          checksum: 'tampered',
        ),
      ],
      quarantined: plan.quarantined,
      digest: plan.digest,
    );

    final outcome = await harness.coordinator.commit(altered);

    expect(outcome, isA<PurgeRejected>());
    expect(harness.mailbox.calls, isEmpty);
  });

  test('an unknown preparation is rejected', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    const plan = PreparedPurge(
      id: 'absent',
      listId: 'git@vger.kernel.org',
      accepted: [],
      quarantined: [],
      digest: 'irrelevant',
    );

    expect(await harness.coordinator.commit(plan), isA<PurgeRejected>());
    expect(harness.mailbox.calls, isEmpty);
  });

  test('a consumed preparation cannot be replayed', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    final plan = await harness.coordinator.prepare(
      'd7',
      'git@vger.kernel.org',
      [candidate],
    );

    await harness.coordinator.commit(plan);
    final replay = await harness.coordinator.commit(plan);

    expect(replay, isA<PurgeRejected>());
    expect(harness.mailbox.calls, ['move:Litzy/Ingested:1']);
  });

  test('a mailbox failure leaves the preparation retryable', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    final plan = await harness.coordinator.prepare(
      'd8',
      'git@vger.kernel.org',
      [candidate],
    );
    harness.mailbox.failNext = true;

    final failed = await harness.coordinator.commit(plan);
    final retry = await harness.coordinator.commit(plan);

    expect(failed, isA<PurgeRejected>());
    expect(retry, isA<PurgeApplied>());
    expect(harness.mailbox.calls, ['move:Litzy/Ingested:1']);
  });

  test('a typed mailbox failure reaches the caller with its code', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    final plan = await harness.coordinator.prepare(
      'd9',
      'git@vger.kernel.org',
      [candidate],
    );
    harness.mailbox.failTypedNext = true;

    await expectLater(
      harness.coordinator.commit(plan),
      throwsA(
        isA<MailboxException>().having(
          (error) => error.code,
          'code',
          'unavailable',
        ),
      ),
    );
    expect(harness.database.isPreparationConsumed(plan.id), isFalse);
    expect(harness.mailbox.calls, isEmpty);
  });

  test('a policy applies only to the list that opted in', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final candidate = _store(harness, 'm1', '1');
    harness.database.setListPolicy(
      'other@example.invalid',
      MailboxAction.expunge.storageName,
    );

    final plan = await harness.coordinator.prepare(
      'd9',
      'git@vger.kernel.org',
      [candidate],
    );
    await harness.coordinator.commit(plan);

    expect(harness.mailbox.calls, ['move:Litzy/Ingested:1']);
  });
}
