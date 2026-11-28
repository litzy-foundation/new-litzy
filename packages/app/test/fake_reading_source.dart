// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:protocol/protocol.dart';

/// Deterministic reading source used by widget and controller tests.
final class FakeReadingSource implements ReadingSource {
  /// Creates a source with optional overrides and an optional failure.
  const FakeReadingSource({
    this.channelViews = const <ChannelView>[],
    this.threadSummaries = const <ThreadSummary>[],
    this.messageList = const <MessageData>[],
    this.failureCode,
    this.failure,
  });

  /// Channels returned by the fake.
  final List<ChannelView> channelViews;

  /// Topic summaries returned by the fake.
  final List<ThreadSummary> threadSummaries;

  /// Messages returned by the fake.
  final List<MessageData> messageList;

  /// Engine code that every call throws when set.
  final String? failureCode;

  /// Arbitrary exception that every call throws when set.
  final Object? failure;

  @override
  Future<List<ChannelView>> channels() async => _result(channelViews);

  @override
  Future<List<ThreadSummary>> threads({String? channelId}) async =>
      _result(threadSummaries);

  @override
  Future<List<MessageData>> thread(String rootId) async => _result(messageList);

  Future<T> _result<T>(T value) async {
    final raised = failure;
    if (raised != null) throw raised;
    final code = failureCode;
    if (code != null) throw ReadingFailure(code);
    return value;
  }
}
