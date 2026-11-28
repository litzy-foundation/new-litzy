// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

final class _ThrowingEngine implements LmlpEngine {
  const _ThrowingEngine(this.error);

  final Object error;

  @override
  Future<LmlpResponse> send(LmlpRequest request) async => throw error;

  @override
  Stream<LmlpEvent> get events => const Stream<LmlpEvent>.empty();

  @override
  Future<void> close() async {}
}

void main() {
  test('a timeout is reported through the reading source port', () async {
    final source = EngineReadingSource(
      const _ThrowingEngine(LmlpTimeoutException('app.list-channels-1')),
    );

    expect(
      source.channels(),
      throwsA(
        isA<ReadingFailure>().having(
          (failure) => failure.code,
          'code',
          AppRequestKeys.transportTimeout,
        ),
      ),
    );
  });

  test(
    'a closed transport is reported through the reading source port',
    () async {
      final source = EngineReadingSource(_ThrowingEngine(StateError('closed')));

      expect(
        source.threads(),
        throwsA(
          isA<ReadingFailure>().having(
            (failure) => failure.code,
            'code',
            AppRequestKeys.transportClosed,
          ),
        ),
      );
    },
  );
}
