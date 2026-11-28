// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:protocol/protocol.dart';

import 'subject_markers.dart';

/// One topic summary in the centre feed.
final class TopicRow extends StatelessWidget {
  /// Creates a topic row with its [summary] and presentation resources.
  const TopicRow({
    super.key,
    required this.summary,
    required this.messages,
    required this.markers,
    required this.onTap,
  });

  /// Topic summary reported by the engine.
  final ThreadSummary summary;

  /// Typed localized messages.
  final AppMessages messages;

  /// Declarative subject markers.
  final SubjectMarkers markers;

  /// Action that opens the conversation.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(summary.subject),
      subtitle: Text(messages.topicCount(summary.messageCount)),
      trailing: markers.isPatch(summary.subject)
          ? Text(messages.patchBadge)
          : null,
      onTap: onTap,
    );
  }
}
