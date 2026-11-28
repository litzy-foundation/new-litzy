// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';

import 'app_bundle.dart';
import 'reading_controller.dart';
import 'reading_view.dart';

/// Channel and cross-channel navigation for the reading interface.
final class ChannelPane extends StatelessWidget {
  /// Creates the channel pane over one [controller].
  const ChannelPane({
    super.key,
    required this.controller,
    required this.bundle,
  });

  /// Controller that handles channel and view selection.
  final ReadingController controller;

  /// Declarative messages used for view labels.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final views = ReadingView.values.where(
      (view) => view != ReadingView.channel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(bundle.messages.channelsTitle)),
        Expanded(
          child: ListView(
            children: [
              for (final view in views)
                ListTile(
                  title: Text(_label(view)),
                  selected: state.view == view,
                  onTap: () => controller.selectView(view),
                ),
              for (final channel in state.channels)
                ListTile(
                  title: Text(channel.label),
                  subtitle: Text(channel.listId),
                  selected:
                      state.view == ReadingView.channel &&
                      state.channelId == channel.id,
                  onTap: () => controller.selectChannel(channel.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _label(ReadingView view) {
    return switch (view) {
      ReadingView.all => bundle.messages.allTopics,
      ReadingView.own => bundle.messages.ownThreads,
      ReadingView.unread => bundle.messages.unreadMail,
      ReadingView.awaitingReply => bundle.messages.awaitingReply,
      ReadingView.channel => bundle.messages.channelsTitle,
    };
  }
}
