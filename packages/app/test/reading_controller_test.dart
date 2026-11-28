// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';
import 'fake_reading_source.dart';

void main() {
  late AppBundle bundle;

  setUp(() {
    bundle = testBundle();
  });

  test('load publishes channels, topics and the channel stage', () async {
    final source = FakeReadingSource(
      channelViews: [defaultGitChannel()],
      threadSummaries: fixtureSummaries(),
    );
    final controller = ReadingController(source, bundle.messages);

    await controller.load();

    expect(controller.state.channels, hasLength(1));
    expect(controller.state.threads, hasLength(1));
    expect(controller.state.view, ReadingView.all);
    expect(controller.state.stage, ReadingStage.channels);
    expect(controller.state.loading, isFalse);
  });

  test(
    'channel and thread selection publish a reconstructed conversation',
    () async {
      final messages = fixtureMessages();
      final source = FakeReadingSource(
        channelViews: [defaultGitChannel()],
        threadSummaries: fixtureSummaries(),
        messageList: messages,
      );
      final controller = ReadingController(source, bundle.messages);
      await controller.load();

      final channel = defaultGitChannel();
      await controller.selectChannel(channel.id);
      expect(controller.state.channelId, channel.id);
      expect(controller.state.view, ReadingView.channel);
      expect(controller.state.stage, ReadingStage.topics);

      await controller.selectThread(messages.first.threadRootId);

      expect(controller.state.messages, messages);
      expect(controller.state.threadId, messages.first.threadRootId);
      expect(controller.state.stage, ReadingStage.conversation);
    },
  );

  test('cross-channel views clear channel results and topics', () async {
    final controller = ReadingController(
      FakeReadingSource(threadSummaries: fixtureSummaries()),
      bundle.messages,
    );
    await controller.load();

    await controller.selectView(ReadingView.unread);

    expect(controller.state.view, ReadingView.unread);
    expect(controller.state.threads, isEmpty);
    expect(controller.state.stage, ReadingStage.topics);
  });

  test('back moves through the mobile stack', () async {
    final messages = fixtureMessages();
    final controller = ReadingController(
      FakeReadingSource(messageList: messages),
      bundle.messages,
    );
    await controller.load();
    await controller.selectThread(messages.first.threadRootId);

    controller.back();
    expect(controller.state.stage, ReadingStage.topics);

    controller.back();
    expect(controller.state.stage, ReadingStage.channels);
  });

  test('a typed failure becomes a localized error key', () async {
    final controller = ReadingController(
      const FakeReadingSource(failureCode: AppRequestKeys.profileNotOpen),
      bundle.messages,
    );

    await controller.load();

    expect(controller.state.errorMessage, bundle.messages.errorProfileNotOpen);
    expect(controller.state.loading, isFalse);
  });

  test('an untyped failure becomes a localized error key', () async {
    final controller = ReadingController(
      FakeReadingSource(failure: StateError('closed')),
      bundle.messages,
    );

    await controller.load();

    expect(controller.state.errorMessage, bundle.messages.errorTransportClosed);
    expect(controller.state.loading, isFalse);
  });
}
