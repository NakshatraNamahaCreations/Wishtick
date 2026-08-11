import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/widgets/sparkle_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The asset filename is spelled "daimond". Nothing about a wrong asset path
  // fails to compile — it throws at paint time, in the app, on a screen nobody
  // may open during review. So the path is checked mechanically.
  test('the asset path resolves to a bundled file', () async {
    expect(SparkleIcon.asset, 'assets/icons/daimond.png');
    final bytes = await rootBundle.load(SparkleIcon.asset);
    expect(bytes.lengthInBytes, greaterThan(0));
  });

  testWidgets('takes its size and colour from the ambient IconTheme', (
    tester,
  ) async {
    // This is what lets a SparkleIcon sit in an occasion map beside plain
    // Icons and be sized by the card that renders it.
    await tester.pumpWidget(
      const MaterialApp(
        // Centred so the icon's own box is measured; MaterialApp.home hands
        // its child tight full-screen constraints, which a bare SizedBox obeys.
        home: Center(
          child: IconTheme(
            data: IconThemeData(size: 48, color: Color(0xFF00FF00)),
            child: SparkleIcon(),
          ),
        ),
      ),
    );

    final icon = tester.widget<ImageIcon>(find.byType(ImageIcon));
    expect(icon.size, isNull, reason: 'nothing should be hard-coded');
    expect(tester.getSize(find.byType(ImageIcon)), const Size(48, 48));

    // The asset is pure black with an alpha channel, so a colour here recolours
    // the glyph rather than washing over it — Image applies srcIn by default,
    // which is why colorBlendMode is left null.
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, const Color(0xFF00FF00));
  });

  testWidgets('an explicit size and colour win over the IconTheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: IconTheme(
            data: IconThemeData(size: 48, color: Color(0xFF00FF00)),
            child: SparkleIcon(size: 22, color: Color(0xFFFF0000)),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ImageIcon)), const Size(22, 22));
    expect(
      tester.widget<Image>(find.byType(Image)).color,
      const Color(0xFFFF0000),
    );
  });
}
