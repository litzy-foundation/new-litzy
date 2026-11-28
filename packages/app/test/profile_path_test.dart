// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the profile file resolves inside the platform support directory',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'litzy-profile-path',
      );
      addTearDown(() => directory.deleteSync(recursive: true));

      final path = await resolveProfilePath(
        'litzy.db',
        supportDirectory: () async => directory,
      );

      expect(path, '${directory.path}${Platform.pathSeparator}litzy.db');
    },
  );
}
