// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'app_test_helpers.dart';

void main() {
  test('each reply receives its visual depth', () {
    final messages = fixtureMessages();
    final depths = const MessageTreeLayout().depthsFor(messages);

    expect(depths[messages.first.id], 0);
    expect(depths[messages.last.id], 1);
  });

  test('a broken parent reference stays at the root', () {
    final message = fixtureMessages().last;
    final orphan = MessageData(
      id: message.id,
      listId: message.listId,
      subject: message.subject,
      fromAddress: message.fromAddress,
      dateEpoch: message.dateEpoch,
      parentId: message.id,
      threadRootId: message.threadRootId,
      body: message.body,
      checksum: message.checksum,
    );
    final depths = const MessageTreeLayout().depthsFor([orphan]);

    expect(depths[orphan.id], 0);
  });
}
