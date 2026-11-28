// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import 'app_request_keys.dart';
import 'reading_failure.dart';

/// Converts an exception at the client boundary into a deterministic failure.
ReadingFailure mapReadingFailure(Object error) => switch (error) {
  ReadingFailure() => error,
  LmlpTimeoutException() => const ReadingFailure(
    AppRequestKeys.transportTimeout,
  ),
  StateError() => const ReadingFailure(AppRequestKeys.transportClosed),
  _ => const ReadingFailure(AppRequestKeys.unexpectedFailure),
};
