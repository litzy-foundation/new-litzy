// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'app_request_keys.dart';
import 'reading_state.dart';

/// Emits machine-readable proof that a compiled client loaded a real profile.
///
/// ADR-0023 requires the agent to launch every binary it builds. The output is
/// made of keys and values rather than localized interface text, so it can be
/// asserted without depending on rendering or language.
final class AcceptanceReporter {
  /// Creates a reporter that writes only when acceptance output is enabled.
  const AcceptanceReporter(this.enabled);

  /// Whether machine-readable output is requested.
  final bool enabled;

  /// Reports the state published after the first load completes.
  void report(ReadingState state) {
    if (!enabled) return;
    stdout.writeln(AppRequestKeys.ready);
    for (final channel in state.channels) {
      stdout.writeln('${AppRequestKeys.channel}=${channel.id}');
    }
    stdout.writeln('${AppRequestKeys.topics}=${state.threads.length}');
  }

  /// Reports a startup exception when acceptance output is enabled.
  void reportFailure(Object error) {
    if (!enabled) return;
    stderr.writeln('${AppRequestKeys.failure}=$error');
  }
}
