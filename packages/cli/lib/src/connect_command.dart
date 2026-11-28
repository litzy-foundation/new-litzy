// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'command_line.dart';

/// Verifies a login and stores the non-secret account settings.
///
/// The password is read at run time through a secure prompt and is never part
/// of the command line.
final class ConnectCommand extends CliCommand {
  /// Creates a connection command for [emailAddress].
  const ConnectCommand(this.emailAddress);

  /// Address typed by the user.
  final String emailAddress;
}
