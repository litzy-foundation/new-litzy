// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Port through which the GUI asks the engine to set up mail accounts.
///
/// Keeping this boundary typed means the widget layer never builds a request
/// or interprets a response itself, as required by R13 and R32. The credential
/// is accepted in memory only and is redacted by its own string conversion.
library;

import 'package:protocol/protocol.dart';

/// Typed account operations used by the setup surface.
abstract interface class AccountSource {
  /// Returns the non-secret settings of stored accounts.
  Future<List<AccountView>> accounts();

  /// Derives endpoints from [emailAddress] without asking for a secret.
  Future<DiscoveredAccount> discover(String emailAddress);

  /// Verifies [credential] and stores the non-secret account settings.
  Future<void> connect({
    required String emailAddress,
    required AccountCredential credential,
    required AccountEndpoint imap,
    required AccountEndpoint smtp,
  });
}
