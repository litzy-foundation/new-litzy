// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import 'app_bundle.dart';
import 'reading_controller.dart';
import 'reading_source.dart';
import 'reading_shell.dart';

/// Root widget of the read-only Litzy client.
final class LitzyApp extends StatefulWidget {
  /// Creates the client over a local [engine] and a [source] that reads it.
  const LitzyApp({
    super.key,
    required this.engine,
    required this.source,
    required this.bundle,
  });

  /// Engine whose isolate is released when the application closes.
  final LmlpEngine engine;

  /// Typed reading source used by the controller.
  final ReadingSource source;

  /// Declarative resources loaded before the application starts.
  final AppBundle bundle;

  @override
  State<LitzyApp> createState() => _LitzyAppState();
}

final class _LitzyAppState extends State<LitzyApp> {
  late final ReadingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReadingController(widget.source, widget.bundle.messages);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.engine.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.bundle.messages.appTitle,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: ReadingShell(controller: _controller, bundle: widget.bundle),
    );
  }
}
