// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The terminal front-end for Litzy.
///
/// R13 requires the CLI to be a thin client over the engine. This package
/// parses arguments, sends typed LMLP requests to the engine isolate and
/// prints structured results; it contains no ingestion or storage rules.
library;

export 'src/command_line.dart';
export 'src/command_runner.dart';
export 'src/snapshot.dart';
