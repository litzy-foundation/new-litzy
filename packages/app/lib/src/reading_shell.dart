// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:material_ui/material_ui.dart';

import 'app_bundle.dart';
import 'desktop_reading_view.dart';
import 'error_banner.dart';
import 'layout_resolver.dart';
import 'mobile_reading_view.dart';
import 'reading_controller.dart';
import 'reading_layout.dart';

/// Chooses the adaptive layout and shows a localized failure banner.
final class ReadingShell extends StatelessWidget {
  /// Creates a shell over immutable reading [state].
  const ReadingShell({
    super.key,
    required this.controller,
    required this.bundle,
  });

  /// Controller that publishes reading state and handles navigation.
  final ReadingController controller;

  /// Declarative resources used by the reading panes.
  final AppBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state;
          return LayoutBuilder(
            builder: (context, constraints) {
              final layout = LayoutResolver(bundle.layout)
                  .resolve(constraints.maxWidth);
              return Column(
                children: [
                  if (state.errorMessage != null)
                    ErrorBanner(
                      message: state.errorMessage!,
                      padding: bundle.layout.cardPadding.toDouble(),
                    ),
                  Expanded(
                    child: switch (layout) {
                      ReadingLayout.desktop => DesktopReadingView(
                        controller: controller,
                        bundle: bundle,
                      ),
                      ReadingLayout.mobile => MobileReadingView(
                        controller: controller,
                        bundle: bundle,
                      ),
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
