// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'body_block.dart';

/// Content that is neither quoted context nor a diff payload.
final class TextBlock extends BodyBlock {
  /// Creates a text block with its verbatim content.
  const TextBlock(this.text);

  /// Block content.
  final String text;
}
