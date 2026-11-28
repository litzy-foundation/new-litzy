// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  test('the GUI constructs no literal user-visible text', () {
    final lib = Directory(
      '${litzyRoot().path}${Platform.pathSeparator}packages'
      '${Platform.pathSeparator}app${Platform.pathSeparator}lib',
    );
    final literalWidgets = RegExp(
      r'\b(?:Text|RichText|Tooltip|Semantics|SnackBar|AlertDialog)'
      r'\(\s*[\x27"]',
    );
    final literalProperties = RegExp(
      r'\b(?:title|label|tooltip|hintText|errorText|semanticButtonLabel|'
      r'semanticsLabel|message):\s*[\x27"]',
    );
    final violations = <String>[];

    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (literalWidgets.hasMatch(source) ||
          literalProperties.hasMatch(source)) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty);
  });
}
