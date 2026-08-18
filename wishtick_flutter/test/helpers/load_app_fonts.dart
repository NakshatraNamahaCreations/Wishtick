import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_typography.dart';

/// Loads the bundled Montserrat and Cormorant Garamond faces into the test
/// binding.
///
/// **Call this from `setUpAll` in any test that asserts geometry.** Flutter's
/// default test font (Ahem) draws every glyph as a full-em square, so text
/// measures far wider than it really is. That does not just make assertions
/// imprecise — it actively *hides* layout bugs: a Column that has collapsed to
/// its content can still look full-width and centred, because the fake glyphs
/// happen to fill the view. The left-hugging splash and the overlapping
/// Continue badge both shipped past tests for exactly that reason.
///
/// Silently does nothing if a font file is missing, so a checkout without the
/// binary assets still runs the rest of the suite rather than erroring out.
Future<void> loadAppFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  await load(AppTypography.bodyFamily, 'assets/fonts/Montserrat.ttf');
  await load(AppTypography.displayFamily, 'assets/fonts/CormorantGaramond.ttf');
}
