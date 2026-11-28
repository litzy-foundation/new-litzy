// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Minimal immutable input accepted by the JWZ thread builder.
library;

import '../text_tokens.dart';

/// One message reduced to the headers needed for threading.
final class ThreadableInput {
  /// Creates a threadable value with an optional decoded subject.
  ThreadableInput(this.messageId, List<String> references, {this.subject})
    : references = List.unmodifiable(references);

  /// Message identifier including angle brackets, or null when missing.
  final String? messageId;

  /// References in header order, root first.
  final List<String> references;

  /// Decoded subject used by the optional subject grouping pass.
  final String? subject;

  /// Identifier used when the source message has none.
  String identifierWithFallback(int sequence) =>
      messageId ??
      '${TextTokens.angleOpen}${TextTokens.missingPrefix}$sequence'
          '${TextTokens.atSign}${TextTokens.localhost}${TextTokens.angleClose}';
}
