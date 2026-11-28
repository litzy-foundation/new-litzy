// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import 'reading_stage.dart';
import 'reading_view.dart';

/// Immutable state published by the reading controller.
final class ReadingState {
  /// Creates an empty state.
  const ReadingState({
    this.channels = const <ChannelView>[],
    this.threads = const <ThreadSummary>[],
    this.messages = const <MessageData>[],
    this.view = ReadingView.all,
    this.channelId,
    this.threadId,
    this.stage = ReadingStage.channels,
    this.errorMessage,
    this.loading = false,
  });

  static const Object _unset = Object();

  /// Persisted channels available for selection.
  final List<ChannelView> channels;

  /// Topic summaries in the selected view.
  final List<ThreadSummary> threads;

  /// Messages in the selected conversation.
  final List<MessageData> messages;

  /// Currently selected channel view.
  final ReadingView view;

  /// Identifier of the selected channel, or null for a cross-channel view.
  final String? channelId;

  /// Identifier of the selected conversation root, or null before selection.
  final String? threadId;

  /// Pane shown by the mobile navigation stack.
  final ReadingStage stage;

  /// Localized error message, or null when there is no error.
  final String? errorMessage;

  /// Whether a typed request is in flight.
  final bool loading;

  /// Returns a copy with the supplied fields replaced.
  ReadingState copyWith({
    List<ChannelView>? channels,
    List<ThreadSummary>? threads,
    List<MessageData>? messages,
    ReadingView? view,
    Object? channelId = _unset,
    Object? threadId = _unset,
    ReadingStage? stage,
    Object? errorMessage = _unset,
    bool? loading,
  }) {
    return ReadingState(
      channels: channels ?? this.channels,
      threads: threads ?? this.threads,
      messages: messages ?? this.messages,
      view: view ?? this.view,
      channelId: identical(channelId, _unset)
          ? this.channelId
          : channelId as String?,
      threadId: identical(threadId, _unset)
          ? this.threadId
          : threadId as String?,
      stage: stage ?? this.stage,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      loading: loading ?? this.loading,
    );
  }
}
