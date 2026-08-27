import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mechanically enforces the design-system rules from `plan.md` §4.
///
/// Colour consistency is a promise the codebase has to keep on its own — a
/// review guideline decays, a failing test does not. If this test fails, move
/// the offending colour into `AppPalette` and reference it through a semantic
/// token instead of adding an exemption.
void main() {
  final libDir = Directory('lib');

  /// The only files permitted to name a colour directly. `hex_color.dart`
  /// carries no colour of its own — it constructs [Color] from *server data*
  /// (taxonomy swatches) and is the sanctioned seam for that.
  const colorLiteralAllowlist = {
    'lib/core/theme/app_palette.dart',
    'lib/core/theme/hex_color.dart',
  };

  /// Widgets read tokens through `context.colors` / `context.gradients`; only
  /// the theme layer is allowed to touch the palette.
  const paletteImportAllowlist = {
    'lib/core/theme/app_palette.dart',
    'lib/core/theme/app_colors.dart',
    'lib/core/theme/app_gradients.dart',
  };

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String normalize(String path) => path.replaceAll(r'\', '/');

  test('no colour literals outside the palette', () {
    // Color(0x…), Color.fromARGB(…), Colors.red — every way to *name* a colour.
    // Color.lerp/alphaBlend and friends only combine colours they were handed,
    // so they introduce no new value and are not matched.
    //
    // `Color(` is matched only in front of a numeric literal, for the same
    // reason: `Color(someStoredValue)` converts a value it was handed — the
    // invitation designer stores a host-picked ink as an int and rebuilds it
    // per layer — and names no colour of its own.
    final literal = RegExp(
      r'\bColor\s*\(\s*[0-9]|\bColor\.from\w+\s*\(|\bColors\s*\.\s*\w+',
    );
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final path = normalize(file.path);
      if (colorLiteralAllowlist.contains(path)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        // `Colors.transparent` is a semantic absence of paint, not a brand
        // colour, so it carries no theming risk.
        final stripped = line.replaceAll('Colors.transparent', '');
        if (literal.hasMatch(stripped)) {
          offenders.add('$path:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Colour literals must live in AppPalette and reach widgets through '
          'semantic tokens (context.colors.*). Offending lines:\n'
          '${offenders.join('\n')}',
    );
  });

  test('AppPalette is imported only by the theme layer', () {
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final path = normalize(file.path);
      if (paletteImportAllowlist.contains(path)) continue;

      if (file.readAsStringSync().contains('app_palette.dart')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Only the theme layer may import AppPalette; widgets use '
          'context.colors.*. Offending files:\n${offenders.join('\n')}',
    );
  });
}
