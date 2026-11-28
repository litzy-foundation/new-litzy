// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';

import 'app_bundle.dart';
import 'body_block_view.dart';

/// Renders one message body as semantic blocks from the core analyzer.
final class MessageBodyView extends StatelessWidget {
  /// Creates a body view for normalized plain text.
  const MessageBodyView({super.key, required this.body, required this.bundle});

  /// Raw message body returned by the engine.
  final String body;

  /// Declarative messages and theme tokens.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    final analysis = const QuoteAndDiffAnalyzer().analyze(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in analysis.blocks)
          BodyBlockView(
            block: block,
            messages: bundle.messages,
            theme: bundle.theme,
          ),
      ],
    );
  }
}
