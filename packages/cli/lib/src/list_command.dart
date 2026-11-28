// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'command_line.dart';

/// Lists topic summaries for one channel or for every channel.
final class ListCommand extends CliCommand {
  /// Creates a topic list command for [channelId], or for all channels.
  const ListCommand([this.channelId]);

  /// Identifier of the channel to read, or null for every channel.
  final String? channelId;
}
