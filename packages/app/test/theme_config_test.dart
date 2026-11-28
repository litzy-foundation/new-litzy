// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Quiet Workshop tokens load from a versioned document', () {
    final theme = ThemeConfig.fromYaml('''
version: 1
style_name: Quiet Workshop
monospace_font: monospace
surface_color: "#FFFFFFFF"
surface_alt_color: "#FFF5F6F7"
text_color: "#FF1A1C1E"
muted_text_color: "#FF5C636A"
accent_color: "#FF2E7D32"
border_color: "#FFD6DBE0"
diff_color: "#FF1B5E20"
quote_color: "#FF607D8B"
spacing_unit: 8.0
card_radius: 8.0
body_text_scale: 1.0
focus_width: 2.0
reduced_motion_ms: 0
''');
    expect(theme.styleName, 'Quiet Workshop');
    expect(theme.accentColor.toARGB32(), 0xFF2E7D32);
    expect(theme.spacingUnit, 8.0);
    expect(theme.focusWidth, 2.0);
    expect(theme.reducedMotion, Duration.zero);
  });

  test('an unsupported token version is rejected', () {
    expect(
      () => ThemeConfig.fromYaml(
        'version: 2${TextTokens.lineFeed}style_name: Other${TextTokens.lineFeed}',
      ),
      throwsA(isA<ConfigurationException>()),
    );
  });
}
