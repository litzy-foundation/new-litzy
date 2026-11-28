// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  test('the declarative marker recognizes ordinary and versioned patches', () {
    final markers = SubjectMarkers.fromYaml(
      resourceText('data/ui/subject_markers.yaml'),
    );

    expect(markers.isPatch('[PATCH] a change'), isTrue);
    expect(markers.isPatch('[PATCH v2 1/3] a change'), isTrue);
    expect(markers.isPatch('Re: a discussion'), isFalse);
  });
}
