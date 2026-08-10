import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../data/events_repository.dart';

/// "Download Guest List" (`4096:206`) — pick a format, or cancel.
///
/// Returns the chosen format, or null if the host backed out. Doing the
/// download here would trap the progress indicator inside a sheet that the
/// share sheet then covers, so the caller owns the fetch.
Future<GuestListFormat?> showGuestListDownloadSheet(BuildContext context) {
  return showModalBottomSheet<GuestListFormat>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DownloadSheet(),
  );
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet();

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  /// PDF is pre-selected in the design — it is the one format a host can send
  /// to a venue without explaining it.
  GuestListFormat _format = GuestListFormat.pdf;

  static const _icons = {
    GuestListFormat.pdf: Icons.picture_as_pdf_outlined,
    GuestListFormat.xlsx: Icons.table_chart_outlined,
    GuestListFormat.csv: Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The floating close button sitting above the sheet's lip.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Material(
            color: colors.surfaceAlt,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Icon(
                  Icons.close,
                  size: AppSizes.iconMd,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Download Guest List',
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose format to export the guest list',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final format in GuestListFormat.values) ...[
                  _FormatRow(
                    format: format,
                    icon: _icons[format] ?? Icons.insert_drive_file_outlined,
                    selected: format == _format,
                    onTap: () => setState(() => _format = format),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(_format),
                        child: const Text('Download'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.format,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final GuestListFormat format;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Semantics(
          selected: selected,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.optionFill,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.iconMd,
                    color: colors.primaryMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        format.label,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        format.blurb,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _RadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: AppSizes.iconLg,
      height: AppSizes.iconLg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? colors.primary : colors.outline,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: AppSizes.iconSm, color: colors.onPrimary)
          : null,
    );
  }
}
