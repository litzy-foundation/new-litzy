// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Semantic analysis of plain-text bodies into quotes, prose and patches.
///
/// The rules are restored from the preserved local implementation and adapted
/// to use named text tokens instead of raw control characters. The GUI folds
/// quote blocks and renders diff blocks from this result without re-parsing
/// the body.
library;

import '../text_tokens.dart';
import 'body_analysis.dart';
import 'body_block.dart';

/// Splits normalized plain text into collapsible semantic blocks.
final class QuoteAndDiffAnalyzer {
  /// Creates an analyzer with no mutable state.
  const QuoteAndDiffAnalyzer();

  static final String _quoteChar = RegExp.escape(TextTokens.quoteMarker);
  static final String _spaceChar = RegExp.escape(TextTokens.space);
  static final String _tabChar = RegExp.escape(TextTokens.horizontalTab);
  static final String _hyphenChar = RegExp.escape(TextTokens.hyphen);
  static final String _plusChar = RegExp.escape(TextTokens.plus);

  static final RegExp _quoteStart = RegExp(
    '^((?:$_quoteChar[$_spaceChar$_tabChar]?)+)',
  );
  static final RegExp _diffFileHeader = RegExp(
    '^(${_hyphenChar * 3}|${_plusChar * 3}) (\\S+/\\S+)',
  );
  static final RegExp _hunkHeader = RegExp(r'^@@ -\d+(,\d+)? \+\d+(,\d+)? @@');
  static final RegExp _diffIndexLine = RegExp(
    r'^(diff --git|index [0-9a-f]+\.\.[0-9a-f]+|new file mode|'
    r'deleted file mode|GIT binary patch)',
  );

  /// Analyzes [body] into ordered semantic blocks.
  BodyAnalysis analyze(String body) {
    final blocks = <BodyBlock>[];
    final diffBuffer = StringBuffer();
    final diffHeaders = <String>[];
    final textBuffer = StringBuffer();
    final quoteBuffer = StringBuffer();
    var inDiff = false;
    var quoteLevel = 0;
    var hunkCount = 0;

    void flushDiff() {
      if (diffBuffer.isNotEmpty) {
        blocks.add(
          DiffBlock(
            diffBuffer.toString().trimRight(),
            List.unmodifiable(diffHeaders),
            hunkCount,
          ),
        );
        diffBuffer.clear();
        diffHeaders.clear();
        hunkCount = 0;
      }
      inDiff = false;
    }

    void closeText() {
      final trimmed = textBuffer.toString().trimRight();
      textBuffer.clear();
      if (trimmed.isNotEmpty) {
        blocks.add(TextBlock(trimmed));
      }
    }

    void closeQuote() {
      final trimmed = quoteBuffer.toString().trimRight();
      quoteBuffer.clear();
      if (quoteLevel > 0 && trimmed.isNotEmpty) {
        blocks.add(QuoteBlock(quoteLevel, trimmed));
      }
      quoteLevel = 0;
    }

    for (final line in body.split(TextTokens.lineFeed)) {
      final trimmed = line.trimRight();
      final looksDiffy =
          _diffFileHeader.hasMatch(trimmed) ||
          _hunkHeader.hasMatch(trimmed) ||
          _diffIndexLine.hasMatch(trimmed) ||
          (inDiff &&
              (trimmed.startsWith(TextTokens.hyphen) ||
                  trimmed.startsWith(TextTokens.plus) ||
                  trimmed.startsWith(TextTokens.space)));

      if (looksDiffy) {
        closeText();
        closeQuote();
        inDiff = true;
        final fileHeader = _diffFileHeader.firstMatch(trimmed);
        if (fileHeader != null) {
          diffHeaders.add(fileHeader.group(2)!.trim());
        }
        if (_hunkHeader.hasMatch(trimmed)) {
          hunkCount++;
        }
        diffBuffer.writeln(trimmed);
        continue;
      }

      if (inDiff) {
        flushDiff();
      }

      final quoteMatch = _quoteStart.firstMatch(trimmed);
      if (quoteMatch != null) {
        final matched = quoteMatch.group(1)!;
        final level = matched.split(TextTokens.quoteMarker).length - 1;
        if (level != quoteLevel) {
          closeQuote();
          quoteLevel = level;
        }
        closeText();
        quoteBuffer.writeln(trimmed.substring(quoteMatch.end));
        continue;
      }

      closeQuote();
      textBuffer.writeln(trimmed);
    }

    closeText();
    closeQuote();
    flushDiff();
    return BodyAnalysis(List.unmodifiable(blocks));
  }
}
