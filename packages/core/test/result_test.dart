// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  test('a successful result carries its value', () {
    const result = Ok<int>(7);
    expect(result.isOk, isTrue);
    expect(result.value, 7);
  });

  test('a failed result carries a stable code', () {
    const result = Err<int>('bad_input', 'value must be positive');
    expect(result.isOk, isFalse);
    expect(result.code, 'bad_input');
    expect(result.message, 'value must be positive');
  });
}
