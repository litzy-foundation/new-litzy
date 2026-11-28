// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import 'app_bundle.dart';
import 'message_body_view.dart';

/// One message in a branch-aware conversation.
final class MessageCard extends StatelessWidget {
  /// Creates a card for [message] at visual [depth].
  const MessageCard({
    super.key,
    required this.message,
    required this.depth,
    required this.bundle,
  });

  /// Message reported by the engine.
  final MessageData message;

  /// Number of ancestors shown before this message.
  final int depth;

  /// Declarative resources used by the body.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    final padding = bundle.layout.cardPadding.toDouble();
    return Padding(
      padding: EdgeInsets.only(
        left: padding + depth * bundle.layout.threadIndent,
        right: padding,
        top: padding,
        bottom: padding,
      ),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.subject),
              Text(message.fromAddress),
              MessageBodyView(body: message.body, bundle: bundle),
            ],
          ),
        ),
      ),
    );
  }
}
