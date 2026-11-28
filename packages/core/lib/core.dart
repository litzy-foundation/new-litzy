// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Deterministic domain values shared by the engine and its front-ends.
///
/// Failures are represented as values rather than exceptions across
/// boundaries, as required by R5 and R16. Thread and body algorithms are pure
/// functions so both front-ends can use them without duplicating rules.
library;

export 'src/body/body_analysis.dart';
export 'src/body/body_block.dart';
export 'src/body/quote_and_diff_analyzer.dart';
export 'src/result.dart';
export 'src/text_tokens.dart';
export 'src/threading/jwz_thread_builder.dart';
export 'src/threading/thread_node.dart';
export 'src/threading/threadable_input.dart';
