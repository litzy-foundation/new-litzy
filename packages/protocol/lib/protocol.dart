// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Typed messages and the in-process transport shared by every Litzy front-end.
///
/// The protocol is the only dependency a GUI or a CLI has on the engine, as
/// required by R13 and ADR-0010. Messages stay typed across the isolate
/// boundary because R32 removes serialisation from that hop.
library;

export 'src/engine.dart';
export 'src/message.dart';
export 'src/transport.dart';
