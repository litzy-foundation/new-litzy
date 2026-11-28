// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Port that verifies an IMAP login without changing a mailbox.
///
/// The verifier is injected so tests never contact a real provider and so the
/// setup service does not own socket code.
library;

import 'package:protocol/protocol.dart';

/// Checks that a credential authenticates on one IMAP endpoint.
abstract interface class AccountLoginVerifier {
  /// Verifies [credential] for [username] at [endpoint].
  ///
  /// An implementation must not select a mailbox or change any message.
  Future<void> verify({
    required AccountEndpoint endpoint,
    required String username,
    required AccountCredential credential,
  });
}
