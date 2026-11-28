// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:flutter/services.dart';
import 'package:l10n/l10n.dart';

import 'app_asset_keys.dart';
import 'layout_config.dart';
import 'profile_config.dart';
import 'subject_markers.dart';
import 'theme_config.dart';

/// Immutable set of declarative resources loaded before the client starts.
final class AppBundle {
  /// Creates a bundle from already parsed resources.
  const AppBundle({
    required this.messages,
    required this.layout,
    required this.theme,
    required this.markers,
    required this.profile,
  });

  /// Loads every resource through [bundle], or through the root asset bundle.
  static Future<AppBundle> load([AssetBundle? bundle]) async {
    final selected = bundle ?? rootBundle;
    final messagesSource = await selected.loadString(AppAssetKeys.messages);
    return AppBundle(
      messages: AppMessages(FluentCatalog.parse(messagesSource)),
      layout: await LayoutConfig.load(selected),
      theme: await ThemeConfig.load(selected),
      markers: await SubjectMarkers.load(selected),
      profile: await ProfileConfig.load(selected),
    );
  }

  /// Typed application messages.
  final AppMessages messages;

  /// Adaptive layout measurements.
  final LayoutConfig layout;

  /// Theme tokens for message bodies.
  final ThemeConfig theme;

  /// Subject markers used by topic rows.
  final SubjectMarkers markers;

  /// Local profile defaults.
  final ProfileConfig profile;
}
