// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'body_block.dart';

/// A run of lines quoted at one citation level.
final class QuoteBlock extends BodyBlock {
  /// Creates a quote block at [level] with its verbatim lines.
  const QuoteBlock(this.level, this.text);

  /// Citation depth, where one represents a single quote marker.
  final int level;

  /// Verbatim quoted lines.
  final String text;

  /// Content with the leading citation markers removed.
  String get unindented => text
      .split(TextTokens.lineFeed)
      .map(_stripMarker)
      .join(TextTokens.lineFeed);

  static String _stripMarker(String line) {
    var end = 0;
    while (end < line.length && line[end] == TextTokens.quoteMarker) {
      end++;
      if (end < line.length && line[end] == TextTokens.space) {
        end++;
      } else if (end < line.length && line[end] == TextTokens.horizontalTab) {
        end++;
      }
    }
    return line.substring(end);
  }
}
