// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Account setup surface of the Flutter client.
///
/// The form collects an email address and an obscured password, shows only
/// non-secret derived endpoints and delegates the secure flow to a
/// `SetupController`. Every visible sentence comes from the Fluent catalogue.
library;

import 'package:material_ui/material_ui.dart';

import 'setup_controller.dart';
import 'setup_state.dart';
import 'theme_config.dart';

/// Form that connects a mail account or defers to public reading.
final class SetupScreen extends StatefulWidget {
  /// Creates a setup surface driven by [controller] with declarative [theme].
  const SetupScreen({
    super.key,
    required this.controller,
    required this.theme,
    this.onSkip,
  });

  /// Controller that performs the secure account flow.
  final SetupController controller;

  /// Declarative spacing tokens shared by every Litzy surface.
  final ThemeConfig theme;

  /// Called when the user chooses to read public lists without an account.
  final VoidCallback? onSkip;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

final class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.controller.messages;
    return Scaffold(
      appBar: AppBar(title: Text(messages.setupTitle)),
      body: SafeArea(
        child: ValueListenableBuilder<SetupState>(
          valueListenable: widget.controller.state,
          builder: (context, state, _) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(widget.theme.spacingUnit * 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(messages.setupDescription),
                    SizedBox(height: widget.theme.spacingUnit * 2),
                    TextField(
                      key: const Key('setup.email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: messages.setupEmailLabel,
                      ),
                    ),
                    SizedBox(height: widget.theme.spacingUnit * 1.5),
                    TextField(
                      key: const Key('setup.password'),
                      controller: _password,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: messages.setupPasswordLabel,
                      ),
                    ),
                    SizedBox(height: widget.theme.spacingUnit * 2),
                    if (state.message.isNotEmpty)
                      Text(state.message, key: const Key('setup.message')),
                    if (state.discovered != null)
                      Text(
                        messages.setupEndpoints(
                          _endpoint(
                            state.discovered!.imap.host,
                            state.discovered!.imap.port,
                          ),
                          _endpoint(
                            state.discovered!.smtp.host,
                            state.discovered!.smtp.port,
                          ),
                        ),
                        key: const Key('setup.endpoints'),
                      ),
                    SizedBox(height: widget.theme.spacingUnit * 2),
                    FilledButton(
                      key: const Key('setup.connect'),
                      onPressed:
                          state.stage == SetupStage.discovering ||
                              state.stage == SetupStage.connecting
                          ? null
                          : _submit,
                      child: Text(messages.setupConnectAction),
                    ),
                    TextButton(
                      key: const Key('setup.clear'),
                      onPressed: _clear,
                      child: Text(messages.setupClearAction),
                    ),
                    TextButton(
                      key: const Key('setup.skip'),
                      onPressed: widget.onSkip,
                      child: Text(messages.setupSkipAction),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final address = _email.text;
    final password = _password.text;
    _password.clear();
    await widget.controller.submit(address, password);
  }

  void _clear() {
    _email.clear();
    _password.clear();
    widget.controller.clear();
  }

  String _endpoint(String host, int port) => '$host:$port';
}
