// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('the protocol line ending joins the named characters', () {
    expect(
      TextTokens.protocolLineEnding,
      '${TextTokens.carriageReturn}${TextTokens.lineFeed}',
    );
  });

  test('ordinary text has no control character', () {
    expect(
      TextTokens.containsControlCharacter('user@example.invalid'),
      isFalse,
    );
  });

  test('every named control character is detected', () {
    final controls = [
      TextTokens.nullCharacter,
      TextTokens.horizontalTab,
      TextTokens.lineFeed,
      TextTokens.carriageReturn,
      String.fromCharCode(TextTokens.deleteCodeUnit),
    ];
    for (final control in controls) {
      expect(
        TextTokens.containsControlCharacter('safe${control}text'),
        isTrue,
        reason: 'a control character must never pass validation',
      );
    }
  });
}
