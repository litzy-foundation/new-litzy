// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'command_line.dart';

/// Shows one reconstructed thread.
final class ShowCommand extends CliCommand {
  /// Creates a show command for [rootId].
  const ShowCommand(this.rootId);

  /// Identifier of the thread root.
  final String rootId;
}
