// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';

import 'app_bundle.dart';
import 'channel_pane.dart';
import 'reading_controller.dart';
import 'thread_pane.dart';
import 'topic_pane.dart';

/// Three-pane reading layout used when the window is wide.
final class DesktopReadingView extends StatelessWidget {
  /// Creates the desktop layout over one [controller].
  const DesktopReadingView({
    super.key,
    required this.controller,
    required this.bundle,
  });

  /// Controller shared by all three panes.
  final ReadingController controller;

  /// Declarative resources used by the panes.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: bundle.layout.channelPaneWidth.toDouble(),
          child: ChannelPane(controller: controller, bundle: bundle),
        ),
        Expanded(
          child: TopicPane(controller: controller, bundle: bundle),
        ),
        SizedBox(
          width: bundle.layout.threadPaneWidth.toDouble(),
          child: ThreadPane(controller: controller, bundle: bundle),
        ),
      ],
    );
  }
}
