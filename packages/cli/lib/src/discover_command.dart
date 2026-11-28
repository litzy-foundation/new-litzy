// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'command_line.dart';

/// Derives mail endpoints from an email address without asking for a secret.
final class DiscoverCommand extends CliCommand {
  /// Creates a discovery command for [emailAddress].
  const DiscoverCommand(this.emailAddress);

  /// Address typed by the user.
  final String emailAddress;
}
