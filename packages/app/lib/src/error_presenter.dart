// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:l10n/l10n.dart';

import 'app_request_keys.dart';
import 'reading_failure.dart';

/// Selects the localized sentence for a deterministic reading failure.
final class ErrorPresenter {
  /// Creates a presenter over [messages].
  const ErrorPresenter(this._messages);

  final AppMessages _messages;

  /// Returns the sentence to show for [failure].
  String present(ReadingFailure failure) {
    return switch (failure.code) {
      AppRequestKeys.profileNotOpen => _messages.errorProfileNotOpen,
      AppRequestKeys.profileOpenFailed => _messages.errorProfileOpenFailed,
      AppRequestKeys.channelListFailed => _messages.errorChannelListFailed,
      AppRequestKeys.threadListFailed => _messages.errorThreadListFailed,
      AppRequestKeys.threadFailed => _messages.errorThreadFailed,
      AppRequestKeys.transportTimeout => _messages.errorTransportTimeout,
      AppRequestKeys.transportClosed => _messages.errorTransportClosed,
      AppRequestKeys.unexpectedFailure => _messages.errorUnexpectedFailure,
      _ => _messages.errorUnknown,
    };
  }
}
