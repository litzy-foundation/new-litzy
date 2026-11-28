// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

/// Data access used by the reading widgets.
///
/// The production implementation sends typed engine requests. Tests supply a
/// fake so widget behaviour can be checked without an isolate.
abstract interface class ReadingSource {
  /// Returns the persisted channels.
  Future<List<ChannelView>> channels();

  /// Returns topic summaries for one channel or for every channel.
  Future<List<ThreadSummary>> threads({String? channelId});

  /// Returns the messages of one reconstructed conversation.
  Future<List<MessageData>> thread(String rootId);
}
