// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import 'app_bundle.dart';
import 'composer_preview.dart';
import 'message_card.dart';
import 'message_tree_layout.dart';
import 'reading_controller.dart';

/// Branch-aware conversation pane for one reconstructed thread.
final class ThreadPane extends StatelessWidget {
  /// Creates the conversation pane over one [controller].
  const ThreadPane({super.key, required this.controller, required this.bundle});

  /// Controller that supplies the selected conversation.
  final ReadingController controller;

  /// Declarative resources used by message bodies.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final depths = const MessageTreeLayout().depthsFor(state.messages);
    final MessageData? first = state.messages.isEmpty
        ? null
        : state.messages.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(bundle.messages.conversationTitle)),
        Expanded(
          child: state.messages.isEmpty
              ? Center(child: Text(bundle.messages.noConversation))
              : ListView.builder(
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    return MessageCard(
                      message: message,
                      depth: depths[message.id] ?? 0,
                      bundle: bundle,
                    );
                  },
                ),
        ),
        if (first != null)
          ComposerPreview(
            to: first.listId,
            cc: bundle.messages.none,
            messages: bundle.messages,
          ),
      ],
    );
  }
}
