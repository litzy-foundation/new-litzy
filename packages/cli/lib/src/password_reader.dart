// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Port for acquiring a password without exposing it in process arguments.
///
/// R37 requires credentials to be acquired inside the application and R55 asks
/// for a non-echoing prompt first. Implementations never place a secret in an
/// argument, environment value, file or diagnostic output.
library;

/// Reads one secret line from the user without ever echoing it.
abstract interface class PasswordReader {
  /// Reads a password after writing [prompt] to the user.
  Future<String> read(String prompt);
}
