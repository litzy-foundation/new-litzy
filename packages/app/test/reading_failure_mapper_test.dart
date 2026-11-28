// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  test('a transport timeout becomes a typed reading failure', () {
    final failure = mapReadingFailure(
      const LmlpTimeoutException('app.list-channels-1'),
    );

    expect(failure.code, AppRequestKeys.transportTimeout);
  });

  test('a closed transport becomes a typed reading failure', () {
    final failure = mapReadingFailure(StateError('closed'));

    expect(failure.code, AppRequestKeys.transportClosed);
  });

  test('an existing reading failure is preserved', () {
    final failure = mapReadingFailure(
      const ReadingFailure(AppRequestKeys.threadFailed),
    );

    expect(failure.code, AppRequestKeys.threadFailed);
  });

  test('an unknown exception becomes a typed reading failure', () {
    final failure = mapReadingFailure(ArgumentError('unexpected'));

    expect(failure.code, AppRequestKeys.unexpectedFailure);
  });
}
