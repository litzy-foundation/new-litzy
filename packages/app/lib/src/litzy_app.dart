// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:security/security.dart';

import 'account_source.dart';
import 'app_bundle.dart';
import 'reading_controller.dart';
import 'reading_source.dart';
import 'reading_shell.dart';
import 'reading_state.dart';
import 'setup_controller.dart';
import 'setup_screen.dart';

/// Root widget of the read-only Litzy client.
final class LitzyApp extends StatefulWidget {
  /// Creates the client over a local [engine] and a [source] that reads it.
  const LitzyApp({
    super.key,
    required this.engine,
    required this.source,
    required this.bundle,
    this.accountSource,
    this.vault,
    this.onLoaded,
    this.onSetupRequired,
  });

  /// Engine whose isolate is released when the application closes.
  final LmlpEngine engine;

  /// Typed reading source used by the controller.
  final ReadingSource source;

  /// Declarative resources loaded before the application starts.
  final AppBundle bundle;

  /// Typed account port used to show setup when no account is stored.
  final AccountSource? accountSource;

  /// Keychain vault used by the setup surface.
  final CredentialVault? vault;

  /// Optional observer called with the state after the first load.
  final void Function(ReadingState state)? onLoaded;

  /// Optional observer called when the setup gate opens.
  final VoidCallback? onSetupRequired;

  @override
  State<LitzyApp> createState() => _LitzyAppState();
}

final class _LitzyAppState extends State<LitzyApp> {
  late final ReadingController _controller;
  SetupController? _setup;
  bool _showSetup = false;

  @override
  void initState() {
    super.initState();
    _controller = ReadingController(widget.source, widget.bundle.messages);
    unawaited(
      _controller.load().then((_) {
        if (mounted) widget.onLoaded?.call(_controller.state);
      }),
    );
    if (widget.accountSource != null && widget.vault != null) {
      _setup = SetupController(
        source: widget.accountSource!,
        vault: widget.vault!,
        messages: widget.bundle.messages,
      );
      unawaited(
        widget.accountSource!
            .accounts()
            .then((accounts) {
              if (mounted && accounts.isEmpty) {
                setState(() => _showSetup = true);
                widget.onSetupRequired?.call();
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _setup?.dispose();
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
        colorScheme:
            ColorScheme.fromSeed(seedColor: widget.bundle.theme.accentColor)
                .copyWith(
                  surface: widget.bundle.theme.surfaceColor,
                  onSurface: widget.bundle.theme.textColor,
                  outline: widget.bundle.theme.borderColor,
                ),
      ),
      home: _showSetup && _setup != null
          ? SetupScreen(
              controller: _setup!,
              theme: widget.bundle.theme,
              onSkip: () => setState(() => _showSetup = false),
            )
          : ReadingShell(controller: _controller, bundle: widget.bundle),
    );
  }
}
