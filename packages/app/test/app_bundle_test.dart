// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeAppTests();

  test('the declared Flutter assets load as one immutable bundle', () async {
    final bundle = await AppBundle.load();

    expect(bundle.messages.appTitle, isNotEmpty);
    expect(bundle.layout.desktopMinWidth, greaterThan(0));
    expect(bundle.theme.diffColor, isNotNull);
    expect(
      bundle.markers.isPatch('${bundle.markers.patchPrefixes.first} subject'),
      isTrue,
    );
    expect(bundle.profile.databasePath, isNotEmpty);
  });
}
