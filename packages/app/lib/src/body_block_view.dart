// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:l10n/l10n.dart';

import 'theme_config.dart';

/// Renders one semantic block produced by `QuoteAndDiffAnalyzer`.
final class BodyBlockView extends StatelessWidget {
  /// Creates a view for one [block].
  const BodyBlockView({
    super.key,
    required this.block,
    required this.messages,
    required this.theme,
  });

  /// Semantic block to render.
  final BodyBlock block;

  /// Typed localized messages.
  final AppMessages messages;

  /// Declarative colours and fonts.
  final ThemeConfig theme;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      TextBlock(:final text) => Text(text),
      QuoteBlock(:final level, :final text) => ExpansionTile(
        title: Text(messages.quotedContext(level)),
        children: [Text(text, style: TextStyle(color: theme.quoteColor))],
      ),
      DiffBlock(:final raw, :final hunkHeaderCount) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(messages.diffSummary(hunkHeaderCount)),
          Text(
            raw,
            style: TextStyle(
              color: theme.diffColor,
              fontFamily: theme.monospaceFont,
            ),
          ),
        ],
      ),
    };
  }
}
