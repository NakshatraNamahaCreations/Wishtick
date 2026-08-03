import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_gradients.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] from the semantic [WishtickColors]
/// tokens. Both themes are produced by the same function, so a component
/// configured here is guaranteed to exist in both.
abstract final class AppTheme {
  static ThemeData get light =>
      _build(WishtickColors.light, WishtickGradients.light);
  static ThemeData get dark =>
      _build(WishtickColors.dark, WishtickGradients.dark);

  static ThemeData _build(WishtickColors c, WishtickGradients g) {
    final textTheme = AppTypography.buildTextTheme(
      primary: c.textPrimary,
      secondary: c.textSecondary,
    );

    final isLight = c.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      extensions: <ThemeExtension<dynamic>>[c, g],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primarySubtle,
        onPrimaryContainer: c.primary,
        secondary: c.accent,
        onSecondary: c.onAccent,
        secondaryContainer: c.accentSubtle,
        onSecondaryContainer: c.accent,
        tertiary: c.celebration,
        onTertiary: c.textPrimary,
        tertiaryContainer: c.celebrationSubtle,
        onTertiaryContainer: c.textPrimary,
        error: c.danger,
        onError: c.onDanger,
        errorContainer: c.dangerSubtle,
        onErrorContainer: c.danger,
        surface: c.surface,
        onSurface: c.textPrimary,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surfaceAlt,
        surfaceContainer: c.surfaceAlt,
        surfaceContainerHigh: c.surfaceAlt,
        surfaceContainerHighest: c.surfaceSunken,
        onSurfaceVariant: c.textSecondary,
        outline: c.border,
        outlineVariant: c.border,
        scrim: c.overlay,
        inverseSurface: c.textPrimary,
        onInverseSurface: c.surface,
        inversePrimary: c.primaryMuted,
        shadow: c.shadow,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textMuted,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          elevation: 0,
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          side: BorderSide(color: c.border),
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: AppTypography.labelMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // A faint lavender, not white — on the beige page a white field reads
        // as a raised card rather than as an input.
        fillColor: c.surfaceAlt,
        constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        // Same size as the value that replaces it, so the field does not
        // appear to change type size as soon as you start typing.
        hintStyle: AppTypography.bodyLarge.copyWith(color: c.textMuted),
        prefixIconColor: c.textPrimary,
        iconColor: c.textMuted,
        // Narrower than M3's 48 default, which pushed the glyph too close to
        // the field's left edge relative to the design.
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: AppSizes.iconLg,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: c.textMuted),
        floatingLabelStyle: AppTypography.bodySmall.copyWith(color: c.primary),
        border: _inputBorder(c.border),
        enabledBorder: _inputBorder(c.border),
        focusedBorder: _inputBorder(c.primary, width: 1.5),
        errorBorder: _inputBorder(c.danger),
        focusedErrorBorder: _inputBorder(c.danger, width: 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.primary,
        disabledColor: c.border,
        labelStyle: AppTypography.labelMedium.copyWith(color: c.textSecondary),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: c.onPrimary,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.overlay,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primaryDeep,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: c.textOnDark,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primarySubtle : c.border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
      ),
      iconTheme: IconThemeData(color: c.textPrimary, size: AppSizes.iconLg),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
