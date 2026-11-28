// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/foundation.dart';
import 'package:l10n/l10n.dart';
import 'package:protocol/protocol.dart';

import 'error_presenter.dart';
import 'reading_failure.dart';
import 'reading_failure_mapper.dart';
import 'reading_source.dart';
import 'reading_stage.dart';
import 'reading_state.dart';
import 'reading_view.dart';

/// Holds the immutable reading state and translates navigation into requests.
final class ReadingController extends ChangeNotifier {
  /// Creates a controller over [source] with localized [messages].
  ReadingController(this._source, AppMessages messages)
    : _errors = ErrorPresenter(messages);

  final ReadingSource _source;
  final ErrorPresenter _errors;
  ReadingState _state = const ReadingState();

  /// Current state published to the widgets.
  ReadingState get state => _state;

  /// Loads channels and topics from every channel.
  Future<void> load() async {
    _set(_state.copyWith(loading: true, errorMessage: null));
    try {
      final channels = await _source.channels();
      final threads = await _source.threads();
      _set(
        _state.copyWith(
          channels: List.unmodifiable(channels),
          threads: List.unmodifiable(threads),
          view: ReadingView.all,
          channelId: null,
          stage: ReadingStage.channels,
          loading: false,
        ),
      );
    } on Object catch (error) {
      _fail(mapReadingFailure(error));
    }
  }

  /// Selects a named channel and loads its topics.
  Future<void> selectChannel(String channelId) async {
    _set(
      _state.copyWith(
        view: ReadingView.channel,
        channelId: channelId,
        threadId: null,
        messages: const <MessageData>[],
        stage: ReadingStage.topics,
        errorMessage: null,
      ),
    );
    await _loadThreads(channelId: channelId);
  }

  /// Selects a channel or cross-channel view.
  Future<void> selectView(ReadingView view) async {
    _set(
      _state.copyWith(
        view: view,
        channelId: null,
        threadId: null,
        messages: const <MessageData>[],
        threads: const <ThreadSummary>[],
        stage: ReadingStage.topics,
        errorMessage: null,
      ),
    );
    if (view == ReadingView.all) await _loadThreads();
  }

  /// Selects a topic and loads its reconstructed conversation.
  Future<void> selectThread(String rootId) async {
    _set(_state.copyWith(loading: true, errorMessage: null));
    try {
      final messages = await _source.thread(rootId);
      _set(
        _state.copyWith(
          messages: List.unmodifiable(messages),
          threadId: rootId,
          stage: ReadingStage.conversation,
          loading: false,
        ),
      );
    } on Object catch (error) {
      _fail(mapReadingFailure(error));
    }
  }

  /// Returns the mobile stack to the channel pane.
  void showChannels() {
    _set(_state.copyWith(stage: ReadingStage.channels));
  }

  /// Moves the mobile stack one pane back.
  void back() {
    final stage = _state.stage;
    if (stage == ReadingStage.conversation) {
      _set(
        _state.copyWith(
          stage: ReadingStage.topics,
          threadId: null,
          messages: const <MessageData>[],
        ),
      );
      return;
    }
    if (stage == ReadingStage.topics) showChannels();
  }

  Future<void> _loadThreads({String? channelId}) async {
    _set(_state.copyWith(loading: true));
    try {
      final threads = await _source.threads(channelId: channelId);
      _set(
        _state.copyWith(threads: List.unmodifiable(threads), loading: false),
      );
    } on Object catch (error) {
      _fail(mapReadingFailure(error));
    }
  }

  void _fail(ReadingFailure failure) {
    _set(
      _state.copyWith(errorMessage: _errors.present(failure), loading: false),
    );
  }

  void _set(ReadingState state) {
    _state = state;
    notifyListeners();
  }
}
