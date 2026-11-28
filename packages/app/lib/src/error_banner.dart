// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';

/// Shows a localized failure above the reading panes.
final class ErrorBanner extends StatelessWidget {
  /// Creates a banner with an already localized [message] and [padding].
  const ErrorBanner({super.key, required this.message, required this.padding});

  /// Sentence to display.
  final String message;

  /// Declarative padding around the sentence.
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: EdgeInsets.all(padding),
      child: Text(message),
    );
  }
}
