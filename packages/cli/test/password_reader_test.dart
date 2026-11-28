// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:cli/cli.dart';
import 'package:test/test.dart';

final class _FakeInput implements PasswordInput {
  _FakeInput(this.value, {this.terminal = true});

  final String value;
  final bool terminal;
  final List<bool> modes = <bool>[];
  bool current = true;

  @override
  bool get hasTerminal => terminal;

  @override
  bool get echoMode => current;

  @override
  set echoMode(bool mode) {
    current = mode;
    modes.add(mode);
  }

  @override
  String? readLineSync() => value;
}

void main() {
  test('a terminal disables echo, reads the line and restores echo', () async {
    final input = _FakeInput('probe-password');
    final output = StringBuffer();
    final reader = TerminalPasswordReader(input: input, output: output);

    final result = await reader.read('Password: ');

    expect(result, 'probe-password');
    expect(input.modes, [false, true]);
    expect(output.toString(), contains('Password: '));
  });

  test('a pipe is read without changing terminal modes', () async {
    final input = _FakeInput('pipe-password', terminal: false);
    final reader = TerminalPasswordReader(input: input, output: StringBuffer());

    expect(await reader.read('Password: '), 'pipe-password');
    expect(input.modes, isEmpty);
  });

  test('an empty terminal line is reported as an empty password', () async {
    final input = _FakeInput('');

    expect(
      await TerminalPasswordReader(
        input: input,
        output: StringBuffer(),
      ).read('Password: '),
      isEmpty,
    );
  });
}
