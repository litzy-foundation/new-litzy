// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The ordered blocks produced from one plain-text message body.
library;

import '../text_tokens.dart';
import 'body_block.dart';

/// Ordered semantic blocks of a message body.
final class BodyAnalysis {
  /// Creates an analysis over [blocks].
  const BodyAnalysis(this.blocks);

  /// Blocks in source order.
  final List<BodyBlock> blocks;

  /// Fresh prose with quoted context and patches removed.
  String get freshText => [
    for (final block in blocks)
      if (block is TextBlock) block.text,
  ].join(TextTokens.lineFeed).trim();

  /// All patch payloads joined by line feeds.
  String get patchText => [
    for (final block in blocks)
      if (block is DiffBlock) block.raw,
  ].join(TextTokens.lineFeed);

  /// Highest citation level found, or zero when there is no quotation.
  int get maxQuoteLevel => blocks.whereType<QuoteBlock>().fold(
    0,
    (maximum, block) => block.level > maximum ? block.level : maximum,
  );
}
