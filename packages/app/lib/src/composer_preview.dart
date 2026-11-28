// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';
import 'package:l10n/l10n.dart';

/// Read-only recipient preview for the composer reserved by ADR-0020.
final class ComposerPreview extends StatelessWidget {
  /// Creates a preview with localized [messages].
  const ComposerPreview({
    super.key,
    required this.to,
    required this.cc,
    required this.messages,
  });

  /// Address that would receive a future reply.
  final String to;

  /// Localized word shown when the Cc list is empty.
  final String cc;

  /// Typed localized messages.
  final AppMessages messages;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(messages.composerPreview(to, cc)));
  }
}
