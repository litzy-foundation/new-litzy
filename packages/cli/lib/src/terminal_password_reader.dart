// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Terminal implementation of secure password entry.
///
/// A terminal is switched to no-echo before the line is read; a pipe cannot
/// echo, so it is read unchanged. The prompt goes to standard error so the
/// structured result on standard output remains parseable.
library;

import 'dart:io';

import 'password_input.dart';
import 'password_reader.dart';
import 'process_password_input.dart';

/// Reads a password from standard input with echo disabled when possible.
final class TerminalPasswordReader implements PasswordReader {
  /// Creates a reader over injected ports for deterministic tests.
  TerminalPasswordReader({PasswordInput? input, StringSink? output})
    : input = input ?? const ProcessPasswordInput(),
      output = output ?? stderr;

  /// Source of the secret line.
  final PasswordInput input;

  /// Sink that receives only the prompt and a trailing line ending.
  final StringSink output;

  @override
  Future<String> read(String prompt) async {
    output.write(prompt);
    if (!input.hasTerminal) return input.readLineSync() ?? '';
    final previous = input.echoMode;
    input.echoMode = false;
    try {
      final value = input.readLineSync();
      output.writeln();
      return value ?? '';
    } finally {
      input.echoMode = previous;
    }
  }
}
