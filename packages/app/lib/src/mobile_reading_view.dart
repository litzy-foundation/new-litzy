// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';

import 'app_bundle.dart';
import 'channel_pane.dart';
import 'reading_controller.dart';
import 'reading_stage.dart';
import 'thread_pane.dart';
import 'topic_pane.dart';

/// Single-pane navigation stack used on narrow windows and mobile devices.
final class MobileReadingView extends StatelessWidget {
  /// Creates the mobile layout over one [controller].
  const MobileReadingView({
    super.key,
    required this.controller,
    required this.bundle,
  });

  /// Controller that drives stack navigation.
  final ReadingController controller;

  /// Declarative resources used by the panes.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Column(
      children: [
        if (state.stage != ReadingStage.channels)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.back,
              child: Text(bundle.messages.backAction),
            ),
          ),
        Expanded(
          child: switch (state.stage) {
            ReadingStage.channels => ChannelPane(
              controller: controller,
              bundle: bundle,
            ),
            ReadingStage.topics => TopicPane(
              controller: controller,
              bundle: bundle,
            ),
            ReadingStage.conversation => ThreadPane(
              controller: controller,
              bundle: bundle,
            ),
          },
        ),
      ],
    );
  }
}
