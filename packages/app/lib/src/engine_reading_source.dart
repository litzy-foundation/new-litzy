// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import 'app_request_keys.dart';
import 'reading_failure.dart';
import 'reading_failure_mapper.dart';
import 'reading_source.dart';

/// Reads the local profile by sending typed requests to the engine.
final class EngineReadingSource implements ReadingSource {
  /// Creates a source backed by [engine].
  EngineReadingSource(this._engine);

  final LmlpEngine _engine;
  int _sequence = 0;

  @override
  Future<List<ChannelView>> channels() async {
    final response = await _send<ChannelListResponse>(
      AppRequestKeys.listChannels,
      ListChannelsRequest(_nextId(AppRequestKeys.listChannels)),
    );
    return response.channels;
  }

  @override
  Future<List<ThreadSummary>> threads({String? channelId}) async {
    final response = await _send<ThreadListResponse>(
      AppRequestKeys.listThreads,
      ListThreadsRequest(_nextId(AppRequestKeys.listThreads), channelId),
    );
    return response.threads;
  }

  @override
  Future<List<MessageData>> thread(String rootId) async {
    final response = await _send<ThreadResponse>(
      AppRequestKeys.showThread,
      ShowThreadRequest(_nextId(AppRequestKeys.showThread), rootId),
    );
    return response.messages;
  }

  String _nextId(String prefix) {
    _sequence++;
    return '$prefix-$_sequence';
  }

  Future<T> _send<T extends LmlpResponse>(
    String key,
    LmlpRequest request,
  ) async {
    final LmlpResponse response;
    try {
      response = await _engine.send(request);
    } on Object catch (error) {
      throw mapReadingFailure(error);
    }
    if (response is T) return response;
    if (response is ErrorResponse) throw ReadingFailure(response.code);
    throw const ReadingFailure(AppRequestKeys.unexpectedResponse);
  }
}
