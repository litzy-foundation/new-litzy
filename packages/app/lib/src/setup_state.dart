// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Immutable view of the account setup flow shown by the GUI.
///
/// The state deliberately contains no credential material. A password lives
/// only in the obscured field and in the controller call that sends it.
library;

import 'package:protocol/protocol.dart';

/// Step reached by the account setup flow.
enum SetupStage {
  /// No address has been submitted yet.
  idle,

  /// Endpoints are being derived from the address.
  discovering,

  /// Endpoints were derived and can be approved with a password.
  discovered,

  /// The login is being verified.
  connecting,

  /// The login was verified and the account was stored.
  connected,

  /// The flow failed and can be retried.
  failed,
}

/// Snapshot published to the setup surface.
final class SetupState {
  /// Creates a state at [stage] with optional derived endpoints and message.
  const SetupState({
    this.stage = SetupStage.idle,
    this.email = '',
    this.discovered,
    this.message = '',
  });

  /// Current step of the flow.
  final SetupStage stage;

  /// Address typed by the user.
  final String email;

  /// Non-secret endpoints derived from the address.
  final DiscoveredAccount? discovered;

  /// Localized status or failure text, empty when there is none.
  final String message;
}
