// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Requests topic summaries, optionally limited to one channel.
final class ListThreadsRequest extends LmlpRequest {
  /// Creates a thread list request with the given identifier.
  const ListThreadsRequest(super.id, [this.channelId]);

  /// Identifier of the channel to read, or null for every channel.
  final String? channelId;
}
