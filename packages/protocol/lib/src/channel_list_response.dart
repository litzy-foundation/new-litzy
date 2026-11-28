// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Returns the channels persisted in the open profile.
final class ChannelListResponse extends LmlpResponse {
  /// Creates a response with the listed [channels].
  const ChannelListResponse(super.id, this.channels);

  /// Channels ordered by their stable identifier.
  final List<ChannelView> channels;
}
