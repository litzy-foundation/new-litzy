// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Asks the engine to derive mail endpoints from an email address alone.
final class DiscoverAccountRequest extends LmlpRequest {
  /// Creates a discovery request for [emailAddress].
  const DiscoverAccountRequest(super.id, this.emailAddress);

  /// Address typed by the user.
  final String emailAddress;
}
