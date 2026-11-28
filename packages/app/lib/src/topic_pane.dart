// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';

import 'app_bundle.dart';
import 'reading_controller.dart';
import 'reading_state.dart';
import 'reading_view.dart';
import 'topic_row.dart';

/// Topic feed ordered by last activity by the engine.
final class TopicPane extends StatelessWidget {
  /// Creates the topic pane over one [controller].
  const TopicPane({super.key, required this.controller, required this.bundle});

  /// Controller that handles topic selection.
  final ReadingController controller;

  /// Declarative resources used by topic rows.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(_title(state))),
        Expanded(
          child: state.loading && state.threads.isEmpty
              ? Center(child: Text(bundle.messages.loading))
              : state.threads.isEmpty
              ? Center(child: Text(_emptyMessage(state)))
              : ListView.builder(
                  itemCount: state.threads.length,
                  itemBuilder: (context, index) {
                    final summary = state.threads[index];
                    return TopicRow(
                      summary: summary,
                      messages: bundle.messages,
                      markers: bundle.markers,
                      onTap: () => controller.selectThread(summary.rootId),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _title(ReadingState state) {
    if (state.view == ReadingView.channel) {
      for (final channel in state.channels) {
        if (channel.id == state.channelId) return channel.label;
      }
    }
    return bundle.messages.topicsTitle;
  }

  String _emptyMessage(ReadingState state) {
    if (state.view == ReadingView.all || state.view == ReadingView.channel) {
      return bundle.messages.noTopics;
    }
    return bundle.messages.emptyView;
  }
}
