// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Process standard input behind the secure entry port.
///
/// Reading the echo mode of a pipe is not meaningful, so callers consult
/// [PasswordInput.hasTerminal] before touching it.
library;

import 'dart:io';

import 'password_input.dart';

/// Adapts process standard input to the secure entry port.
final class ProcessPasswordInput implements PasswordInput {
  /// Creates an adapter over process standard input.
  const ProcessPasswordInput();

  @override
  bool get hasTerminal => stdin.hasTerminal;

  @override
  bool get echoMode => stdin.echoMode;

  @override
  set echoMode(bool value) => stdin.echoMode = value;

  @override
  String? readLineSync() => stdin.readLineSync();
}
