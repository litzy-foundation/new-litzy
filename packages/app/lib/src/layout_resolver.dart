// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'layout_config.dart';
import 'reading_layout.dart';

/// Chooses the reading layout from a measured width and declarative values.
final class LayoutResolver {
  /// Creates a resolver using [config].
  const LayoutResolver(this._config);

  final LayoutConfig _config;

  /// Returns the layout family for an available [width].
  ReadingLayout resolve(double width) => width >= _config.desktopMinWidth
      ? ReadingLayout.desktop
      : ReadingLayout.mobile;
}
