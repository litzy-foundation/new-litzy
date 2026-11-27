// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:cli/cli.dart';

/// Starts the terminal client and reports one typed result.
Future<void> main(List<String> arguments) async {
  try {
    final result = await runCommand(parseCommandLine(arguments));
    if (result.output.isNotEmpty) stdout.writeln(result.output);
    if (result.error.isNotEmpty) stderr.writeln(result.error);
    exitCode = result.exitCode;
  } on CliUsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  } catch (error) {
    stderr.writeln('client error: $error');
    exitCode = 70;
  }
}
