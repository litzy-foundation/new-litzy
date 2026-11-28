// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Orchestrates account setup between the GUI and the secure ports.
///
/// From one address and one obscured password the controller derives endpoints,
/// stores the secret in the keychain, verifies the login and removes the secret
/// when verification fails. The published state never holds password material
/// (ADR-0025 and R55).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:l10n/l10n.dart';
import 'package:protocol/protocol.dart';
import 'package:security/security.dart';

import 'account_source.dart';
import 'account_source_exception.dart';
import 'setup_state.dart';

/// Drives one account setup attempt at a time.
final class SetupController {
  /// Creates a controller over the account port and the credential vault.
  SetupController({
    required this.source,
    required this.vault,
    required this.messages,
  });

  /// Typed account operations provided by the engine.
  final AccountSource source;

  /// Keychain-backed credential store.
  final CredentialVault vault;

  /// Localized text published to the setup surface.
  final AppMessages messages;

  /// Published snapshot of the current attempt.
  final ValueNotifier<SetupState> state = ValueNotifier(const SetupState());

  /// Derives endpoints and verifies [password] for [email].
  Future<void> submit(String email, String password) async {
    final address = email.trim().toLowerCase();
    if (!_validAddress(address)) {
      _fail(address, null, messages.setupInvalidAddress);
      return;
    }
    if (password.isEmpty) {
      _fail(address, null, messages.passwordRequired);
      return;
    }
    state.value = SetupState(
      stage: SetupStage.discovering,
      email: address,
      message: messages.setupDiscovering,
    );
    final DiscoveredAccount discovered;
    try {
      discovered = await source.discover(address);
    } on AccountSourceException catch (error) {
      _fail(address, null, _message(error.code));
      return;
    } on Object {
      _fail(address, null, messages.setupError);
      return;
    }
    if (discovered.imap.authentication != AccountAuthentication.password ||
        discovered.smtp.authentication != AccountAuthentication.password) {
      _fail(address, discovered, messages.accountUnsupportedAuth);
      return;
    }
    state.value = SetupState(
      stage: SetupStage.connecting,
      email: address,
      discovered: discovered,
      message: messages.setupConnecting,
    );
    final server = Uri(
      scheme: discovered.imap.security == AccountSecurity.implicitTls
          ? 'imaps'
          : 'imap',
      host: discovered.imap.host,
      port: discovered.imap.port,
    );
    try {
      await vault.storePassword(
        server: server,
        username: address,
        password: password,
      );
    } on CredentialException {
      _fail(address, discovered, messages.setupError);
      return;
    }
    try {
      await source.connect(
        emailAddress: address,
        credential: AccountCredential.password(password),
        imap: discovered.imap,
        smtp: discovered.smtp,
      );
      state.value = SetupState(
        stage: SetupStage.connected,
        email: address,
        discovered: discovered,
        message: messages.setupConnected,
      );
    } on Object catch (error) {
      await vault.forgetPassword(server: server, username: address);
      _fail(
        address,
        discovered,
        error is AccountSourceException && error.code == 'unsupported_auth'
            ? messages.accountUnsupportedAuth
            : messages.setupError,
      );
    }
  }

  /// Returns the setup form to its initial state.
  void clear() => state.value = const SetupState();

  /// Releases the published notifier.
  void dispose() => state.dispose();

  void _fail(String email, DiscoveredAccount? discovered, String message) {
    state.value = SetupState(
      stage: SetupStage.failed,
      email: email,
      discovered: discovered,
      message: message,
    );
  }

  String _message(String code) => switch (code) {
    'unsupported_auth' ||
    'authentication_mismatch' => messages.accountUnsupportedAuth,
    _ => messages.setupError,
  };

  bool _validAddress(String value) =>
      value.isNotEmpty && value.split('@').length == 2;
}
