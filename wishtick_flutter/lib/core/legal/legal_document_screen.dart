import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';
import '../theme/theme_extensions.dart';
import '../widgets/circle_back_button.dart';
import '../widgets/sparkle_icon.dart';
import 'legal_document.dart';

/// Renders a [LegalDocument] — the Terms, the Privacy Policy — as something a
/// person will actually read.
///
/// Long legal text fails in two ways: it looks like a wall, and there is no way
/// back to the clause you half-remember. So the page gives it a gradient
/// header with the shape of the document up front, a reading-progress hairline
/// under the app bar, numbered sections with hanging clause numbers, and a
/// contents sheet that scrolls to any of the forty.
///
/// The body is a [SingleChildScrollView] rather than a lazy list on purpose:
/// jumping to a section needs that section's element to exist, and a
/// [ListView] has not built the ones off screen. Forty sections of text is
/// well inside what one layout pass handles.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  final _scroll = ScrollController();

  /// How far the header has scrolled away, 0 → 1. Drives the app bar's fill
  /// and title, kept out of [setState] so a scroll rebuilds the bar alone.
  final _collapse = ValueNotifier(0.0);

  /// How much of the document is behind you, 0 → 1.
  final _progress = ValueNotifier(0.0);

  late final List<GlobalKey> _anchors = List.generate(
    widget.document.sections.length,
    (_) => GlobalKey(),
  );

  /// Where the header stops being visible. Measured against the hero's height
  /// rather than a constant so the fade tracks the actual header.
  static const _heroFade = 180.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _collapse.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scroll.position;
    _collapse.value = (position.pixels / _heroFade).clamp(0.0, 1.0);
    final extent = position.maxScrollExtent;
    _progress.value = extent <= 0
        ? 0
        : (position.pixels / extent).clamp(0.0, 1.0);
  }

  /// Scrolls [index]'s section to just under the app bar.
  ///
  /// Resolved through the viewport rather than `ensureVisible` because the body
  /// runs behind a transparent app bar — `ensureVisible` would park the heading
  /// underneath it.
  Future<void> _jumpTo(int index) async {
    final context = _anchors[index].currentContext;
    if (context == null) return;
    final box = context.findRenderObject()! as RenderBox;
    final inset = MediaQuery.paddingOf(this.context).top + kToolbarHeight;
    final target =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset - inset;
    await _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openContents() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContentsSheet(sections: widget.document.sections),
    );
    if (chosen != null) await _jumpTo(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final document = widget.document;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 2),
        child: ValueListenableBuilder(
          valueListenable: _collapse,
          builder: (context, collapse, _) => _DocumentAppBar(
            title: document.title,
            collapse: collapse,
            progress: _progress,
            onContents: _openContents,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DocumentHero(document: document, onContents: _openContents),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final block in document.intro) ...[
                    _BlockView(block),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  for (var i = 0; i < document.sections.length; i++)
                    _SectionView(
                      key: _anchors[i],
                      section: document.sections[i],
                      first: i == 0,
                    ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _Colophon(document: document),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar that starts invisible over the hero and settles into the page
/// colour once the title has scrolled past.
class _DocumentAppBar extends StatelessWidget {
  const _DocumentAppBar({
    required this.title,
    required this.collapse,
    required this.progress,
    required this.onContents,
  });

  final String title;
  final double collapse;
  final ValueListenable<double> progress;
  final VoidCallback onContents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppBar(
      backgroundColor: colors.background.withValues(alpha: collapse),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      // Fades in over the second half of the collapse so it never crosses the
      // hero's own title on the way up.
      title: Opacity(
        opacity: ((collapse - 0.5) * 2).clamp(0.0, 1.0),
        child: Text(
          title,
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      leadingWidth: AppSizes.minTapTarget + AppSpacing.lg,
      leading: const Padding(
        padding: EdgeInsets.only(left: AppSpacing.lg),
        child: Align(child: CircleBackButton()),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: _CircleAction(
            icon: Icons.format_list_numbered_rounded,
            tooltip: 'Contents',
            onTap: onContents,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) => Opacity(
            opacity: collapse,
            child: LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A disc button matching [CircleBackButton], for the other side of the bar.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: colors.shadow,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(
              icon,
              size: AppSizes.iconMd,
              color: colors.textPrimary,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}

/// The gradient masthead: what this document is, in one screen.
class _DocumentHero extends StatelessWidget {
  const _DocumentHero({required this.document, required this.onContents});

  final LegalDocument document;
  final VoidCallback onContents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onDark = colors.textOnDark;

    return Container(
      decoration: BoxDecoration(
        // The same plum masthead Home wears, so the legal screens read as part
        // of the app rather than a page bolted onto it.
        gradient: context.gradients.header,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        MediaQuery.paddingOf(context).top + kToolbarHeight + AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SparkleIcon(size: AppSizes.iconLg, color: onDark),
          const SizedBox(height: AppSpacing.md),
          Text(
            document.kicker.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: onDark.withValues(alpha: 0.75),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            document.title,
            style: AppTypography.displaySmall.copyWith(color: onDark),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            document.summary,
            style: AppTypography.bodyMedium.copyWith(
              color: onDark.withValues(alpha: 0.85),
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (document.effectiveDate case final date?)
                _HeroPill(icon: Icons.event_available_rounded, label: date),
              _HeroPill(
                icon: Icons.article_outlined,
                label: '${document.sections.length} sections',
              ),
              _HeroPill(
                icon: Icons.schedule_rounded,
                label: '${document.readingMinutes} min read',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // The jump-to-section affordance, offered once where a reader first
          // realises how long this is — the app bar keeps it available after.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onContents,
              icon: const Icon(Icons.list_rounded, size: AppSizes.iconMd),
              label: const Text('Jump to a section'),
              style: TextButton.styleFrom(
                foregroundColor: onDark,
                backgroundColor: onDark.withValues(alpha: 0.14),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                shape: const StadiumBorder(),
                textStyle: AppTypography.labelMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onDark = context.colors.textOnDark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: onDark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: onDark.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: onDark),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(label, style: AppTypography.labelSmall.copyWith(color: onDark)),
        ],
      ),
    );
  }
}

/// One numbered section and everything under it.
class _SectionView extends StatelessWidget {
  const _SectionView({required this.section, required this.first, super.key});

  final LegalSection section;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!first) ...[
          const SizedBox(height: AppSpacing.xxl),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: AppSpacing.xxl),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionBadge(section.number),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  section.title,
                  style: AppTypography.titleLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final block in section.blocks) ...[
          _BlockView(block),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// The section number, set in a soft plum tile.
class _SectionBadge extends StatelessWidget {
  const _SectionBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '$number',
        // `primary` is near-black on the dark ramp; `headlineBrandColor` is the
        // token that stays legible in both themes.
        style: AppTypography.labelMedium.copyWith(
          color: context.headlineBrandColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Dispatches one block to its rendering.
class _BlockView extends StatelessWidget {
  const _BlockView(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    LegalParagraph(:final text, :final emphasis) => _Body(
      text,
      emphasis: emphasis,
    ),
    LegalClause(:final number, :final text, :final items) => _ClauseView(
      number: number,
      text: text,
      items: items,
    ),
    LegalBullets(:final lead, :final items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lead != null) ...[
          _Body(lead),
          const SizedBox(height: AppSpacing.sm),
        ],
        _MarkedList(items: items, lettered: false),
      ],
    ),
    LegalCallout(:final text, :final tone) => _CalloutView(
      text: text,
      tone: tone,
    ),
    LegalContact contact => _ContactCard(contact),
  };
}

/// Body copy, at the one size and leading the whole document uses.
class _Body extends StatelessWidget {
  const _Body(this.text, {this.emphasis = false});

  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: emphasis ? colors.textPrimary : colors.textSecondary,
        fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
        height: 1.65,
      ),
    );
  }
}

/// A clause, its number hanging in the margin beside the text.
///
/// A hanging indent rather than an inline "1.1 " prefix: the numbers line up
/// down the page, which is how you find the clause someone quoted at you.
class _ClauseView extends StatelessWidget {
  const _ClauseView({
    required this.number,
    required this.text,
    required this.items,
  });

  final String number;
  final String text;
  final List<String> items;

  static const _gutter = 42.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _gutter,
            child: Padding(
              // Drops the smaller number onto the body's first baseline.
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                number,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Body(text),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _MarkedList(items: items, lettered: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "(a) … (b) …" or bulleted items under a clause.
class _MarkedList extends StatelessWidget {
  const _MarkedList({required this.items, required this.lettered});

  final List<String> items;
  final bool lettered;

  static const _letters = 'abcdefghijklmnopqrstuvwxyz';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final markStyle = AppTypography.bodyMedium.copyWith(
      color: colors.textMuted,
      fontWeight: FontWeight.w600,
      height: 1.65,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: lettered ? 26 : 18,
                  child: Text(
                    lettered
                        // Past 26 items the source documents run out of
                        // letters too; a bullet is the honest fallback.
                        ? (i < _letters.length ? '(${_letters[i]})' : '•')
                        : '•',
                    style: markStyle,
                  ),
                ),
                Expanded(child: _Body(items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

/// A plain-language summary sitting beside the clauses it summarises.
class _CalloutView extends StatelessWidget {
  const _CalloutView({required this.text, required this.tone});

  final String text;
  final LegalTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, accent, icon) = switch (tone) {
      LegalTone.info => (
        colors.infoSubtle,
        colors.info,
        Icons.info_outline_rounded,
      ),
      LegalTone.good => (
        colors.successSubtle,
        colors.onSuccessSubtle,
        Icons.verified_outlined,
      ),
      LegalTone.caution => (
        colors.warningSubtle,
        colors.onWarningSubtle,
        Icons.error_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In plain English',
                  style: AppTypography.labelSmall.copyWith(
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  text,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A named contact, with the email and phone live rather than printed.
class _ContactCard extends StatelessWidget {
  const _ContactCard(this.contact);

  final LegalContact contact;

  Future<void> _open(BuildContext context, Uri uri, String what) async {
    final launched = await launchUrl(uri);
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $what.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.role.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: context.headlineBrandColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            contact.name,
            style: AppTypography.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (contact.designation case final designation?) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              designation,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (contact.email case final email?) ...[
            const SizedBox(height: AppSpacing.md),
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: email,
              onTap: () => unawaited(
                _open(
                  context,
                  Uri(scheme: 'mailto', path: email),
                  'your mail app',
                ),
              ),
            ),
          ],
          if (contact.phone case final phone?) ...[
            const SizedBox(height: AppSpacing.sm),
            _ContactRow(
              icon: Icons.call_outlined,
              label: phone,
              onTap: () => unawaited(
                _open(context, Uri(scheme: 'tel', path: phone), 'the dialler'),
              ),
            ),
          ],
          if (contact.address case final address?) ...[
            const SizedBox(height: AppSpacing.sm),
            _ContactRow(icon: Icons.place_outlined, label: address),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconMd, color: colors.textMuted),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: onTap == null ? colors.textSecondary : colors.primary,
              decoration: onTap == null ? null : TextDecoration.underline,
              decorationColor: colors.primary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: text,
      ),
    );
  }
}

/// The line that closes the document.
class _Colophon extends StatelessWidget {
  const _Colophon({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Divider(color: colors.border, height: 1),
        const SizedBox(height: AppSpacing.lg),
        SparkleIcon(size: AppSizes.iconSm, color: colors.textMuted),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'End of ${document.title}',
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          document.entity,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// The section index, as a sheet you scroll and tap.
class _ContentsSheet extends StatelessWidget {
  const _ContentsSheet({required this.sections});

  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      // A Material rather than a decorated box: the rows below are ListTiles,
      // whose splashes paint on the nearest Material ancestor — a plain
      // container would sit on top of them and swallow the ink.
      builder: (context, controller) => Material(
        color: colors.background,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Contents',
                    style: AppTypography.titleLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sections.length} sections',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return ListTile(
                    onTap: () => Navigator.of(context).pop(index),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    leading: _SectionBadge(section.number),
                    title: Text(
                      section.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: AppSizes.iconSm,
                      color: colors.textMuted,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
