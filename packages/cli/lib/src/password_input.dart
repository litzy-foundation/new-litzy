// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Port exposing only the input modes needed to read a secret safely.
///
/// The port lets a test replace a terminal with a fake while the production
/// adapter keeps using process standard input.
library;

/// Input modes needed to disable echo while reading a secret.
abstract interface class PasswordInput {
  /// Whether input comes from a terminal rather than a pipe.
  bool get hasTerminal;

  /// Whether the terminal echoes entered characters.
  bool get echoMode;

  /// Changes the terminal echo mode.
  set echoMode(bool value);

  /// Reads one line of input.
  String? readLineSync();
}
