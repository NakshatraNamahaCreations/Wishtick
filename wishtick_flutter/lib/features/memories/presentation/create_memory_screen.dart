import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../events/presentation/widgets/relation_picker_sheet.dart';
import '../../wishmates/domain/wishmate.dart';
import '../../wishmates/presentation/widgets/person_avatar.dart';
import '../../wishmates/presentation/widgets/wishmate_picker_sheet.dart';
import 'create_memory_controller.dart';
import 'widgets/occasion_grid.dart';

/// "Create Memory" (`4104:1539`) — step 1 of two.
class CreateMemoryScreen extends ConsumerStatefulWidget {
  const CreateMemoryScreen({super.key});

  @override
  ConsumerState<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends ConsumerState<CreateMemoryScreen> {
  late final _title = TextEditingController(
    text: ref.read(createMemoryProvider).title,
  );
  late final _description = TextEditingController(
    text: ref.read(createMemoryProvider).description,
  );

  final _scrollController = ScrollController();

  /// One per required field, so a too-early submit can scroll to the first
  /// thing that is actually missing rather than to the top of the form.
  final _fieldKeys = {
    for (final field in MemoryField.values) field: GlobalKey(),
  };

  bool _uploadingCover = false;
  String? _coverError;

  /// Picks the WishMate the memory is for.
  ///
  /// A picker rather than a name field: the server refuses a recipient the
  /// host is not linked to, so anything typed here could only be rejected —
  /// and the account is what lets the capsule reach them when it opens.
  Future<void> _pickRecipient() async {
    final picked = await showWishmatePickerSheet(
      context,
      title: 'Who is this memory for?',
      emptyMessage:
          'A memory is made for a WishMate. Add someone first, and they will '
          'appear here.',
    );
    if (picked == null || !mounted) return;
    ref.read(createMemoryProvider.notifier).setRecipient(picked);
  }

  /// Save & Continue, pressed at any time — including while it looks disabled.
  ///
  /// A greyed-out button that does nothing is the whole complaint: on a form
  /// long enough to scroll, the missing field is usually off screen, and the
  /// button gives no clue which one it is. So it always answers — either by
  /// moving on, or by saying what is missing, outlining it, and scrolling to
  /// it.
  void _onSaveAndContinue() {
    final state = ref.read(createMemoryProvider);
    if (state.step1Complete) {
      unawaited(context.push<void>(AppRoutes.createMemoryUnlock));
      return;
    }

    ref.read(createMemoryProvider.notifier).revealValidation();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(state.missingMessage)));

    // The first one in screen order, so repeated presses walk down the form
    // rather than jumping about.
    final target = _fieldKeys[state.missingStep1.first]?.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: AppDurations.normal,
          curve: Curves.easeOut,
          // Not flush to the top: a field pinned to the very edge of the
          // viewport reads as cut off rather than as the thing being pointed
          // at.
          alignment: 0.15,
        ),
      );
    }
  }

  /// The error under a field, once a too-early submit has revealed them.
  String? _errorFor(CreateMemoryState state, MemoryField field) =>
      state.showValidation && state.missingStep1.contains(field)
      ? 'Required'
      : null;

  @override
  void dispose() {
    _scrollController.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickRelation() async {
    final choice = await showRelationPicker(
      context,
      selectedKey: ref.read(createMemoryProvider).relationKey,
    );
    if (choice == null || !mounted) return;
    ref
        .read(createMemoryProvider.notifier)
        .setRelation(choice.key, choice.label);
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _uploadingCover = true;
      _coverError = null;
    });
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(file: picked, purpose: MediaPurpose.memoryCover);
      if (!mounted) return;
      ref
          .read(createMemoryProvider.notifier)
          .setCover(mediaId: media.id, localPath: picked.path);
    } catch (e) {
      if (mounted) setState(() => _coverError = 'Could not upload that image.');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createMemoryProvider);
    final notifier = ref.read(createMemoryProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Create Memory'),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _SectionHeading('Give Your Memory a Title'),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            maxLength: 140,
            buildCounter: _noCounter,
            decoration: InputDecoration(
              labelText: 'Memory Name *',
              errorText: _errorFor(state, MemoryField.title),
              hintText: "Ananya's Birthday",
            ),
            onChanged: notifier.setTitle,
          ),

          const SizedBox(height: AppSpacing.section),
          _SectionHeading('Who is this memory for?'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _RecipientField(
                  key: _fieldKeys[MemoryField.recipient],
                  person: state.recipient,
                  onTap: _pickRecipient,
                  errorText: _errorFor(state, MemoryField.recipient),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: _RelationField(
                  key: _fieldKeys[MemoryField.relation],
                  label: state.relationLabel,
                  onTap: _pickRelation,
                  errorText: _errorFor(state, MemoryField.relation),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            maxLength: kMemoryDescriptionMax,
            decoration: InputDecoration(
              labelText: 'Description *',
              errorText: _errorFor(state, MemoryField.description),
              hintText:
                  "Let's make her day extra special. Join us in celebrating "
                  "Ananya's birthday.",
            ),
            onChanged: notifier.setDescription,
          ),

          const SizedBox(height: AppSpacing.xl),
          _SectionHeading('What is the occasion?'),
          const SizedBox(height: AppSpacing.lg),
          OccasionGrid(
            selectedKey: state.occasionKey,
            onSelect: notifier.setOccasion,
          ),

          const SizedBox(height: AppSpacing.section),
          _OccasionDatePicker(
            day: state.occasionDay,
            month: state.occasionMonth,
            year: state.occasionYear ?? DateTime.now().year,
            includeYear: state.includeYear,
            onDay: notifier.setOccasionDay,
            onMonth: notifier.setOccasionMonth,
            onYear: notifier.setOccasionYear,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Switch(
                value: state.includeYear,
                onChanged: notifier.setIncludeYear,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Include Year',
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          _SectionHeading('Cover Image'),
          const SizedBox(height: AppSpacing.lg),
          _CoverRow(
            localPath: state.coverLocalPath,
            busy: _uploadingCover,
            onAdd: _uploadingCover ? null : _pickCover,
          ),
          if (_coverError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            WishtickErrorText(_coverError!),
          ],

          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(state.error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _SaveAndContinue(
            enabled: state.step1Complete,
            onPressed: _onSaveAndContinue,
          ),
        ),
      ),
    );
  }
}

/// The plum section headings that split `4104:1539` into four questions.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.titleMedium?.copyWith(
      color: context.headlineBrandColor,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Looks like a dropdown, opens the relation picker sheet (`2252:423`).
class _RelationField extends StatelessWidget {
  const _RelationField({
    required this.label,
    required this.onTap,
    this.errorText,
    super.key,
  });

  final String? label;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Relation *',
          errorText: errorText,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? 'Select',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(
                  color: label == null ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: AppSizes.iconMd,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Select Occasion date" — the three-row wheel on `4104:1539`.
///
/// A wheel rather than a calendar because the value it captures is usually a
/// recurring day-and-month ("17 July"), and a calendar would force a year the
/// host does not mean.
class _OccasionDatePicker extends StatelessWidget {
  const _OccasionDatePicker({
    required this.day,
    required this.month,
    required this.year,
    required this.includeYear,
    required this.onDay,
    required this.onMonth,
    required this.onYear,
  });

  final int day;
  final int month;
  final int year;
  final bool includeYear;
  final ValueChanged<int> onDay;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;

  static const _rowHeight = 44.0;
  static const _visibleRows = 3;

  /// Days in the chosen month, so 31 February cannot be selected.
  int get _daysInMonth => DateTime(year, month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final months = List.generate(
      12,
      (i) => DateFormat('MMMM').format(DateTime(2026, i + 1)),
    );
    final years = List.generate(120, (i) => DateTime.now().year - 100 + i);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Select Occasion date',
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: _rowHeight * _visibleRows,
            child: Stack(
              children: [
                // The selected row's plum band, behind the wheels.
                Center(
                  child: Container(
                    height: _rowHeight,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryDeep,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Wheel(
                        key: const ValueKey('occasion-day'),
                        count: _daysInMonth,
                        selected: day.clamp(1, _daysInMonth) - 1,
                        labelAt: (i) => '${i + 1}',
                        onSelected: (i) => onDay(i + 1),
                      ),
                    ),
                    Expanded(
                      child: _Wheel(
                        key: const ValueKey('occasion-month'),
                        count: 12,
                        selected: month - 1,
                        labelAt: (i) => months[i],
                        onSelected: (i) => onMonth(i + 1),
                      ),
                    ),
                    if (includeYear)
                      Expanded(
                        child: _Wheel(
                          key: const ValueKey('occasion-year'),
                          count: years.length,
                          selected: years
                              .indexOf(year)
                              .clamp(0, years.length - 1),
                          labelAt: (i) => '${years[i]}',
                          onSelected: (i) => onYear(years[i]),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.selected,
    required this.labelAt,
    required this.onSelected,
    super.key,
  });

  final int count;
  final int selected;
  final String Function(int index) labelAt;
  final ValueChanged<int> onSelected;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.selected);

  @override
  void didUpdateWidget(_Wheel old) {
    super.didUpdateWidget(old);
    // Only when something else moved the value — jumping while the user is
    // dragging would fight them.
    if (widget.selected != old.selected &&
        _controller.hasClients &&
        _controller.selectedItem != widget.selected) {
      _controller.jumpToItem(widget.selected);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: _OccasionDatePicker._rowHeight,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: widget.onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (context, i) => Center(
          child: Text(
            widget.labelAt(i),
            style: context.text.titleMedium?.copyWith(
              // The centre row sits on the plum band.
              color: i == widget.selected
                  ? colors.textOnDark
                  : colors.textMuted,
              fontWeight: i == widget.selected
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen cover beside a "+" tile, as `4104:1539` lays it out.
class _CoverRow extends StatelessWidget {
  const _CoverRow({
    required this.localPath,
    required this.busy,
    required this.onAdd,
  });

  final String? localPath;
  final bool busy;
  final VoidCallback? onAdd;

  static const _height = 132.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          if (localPath != null) ...[
            Expanded(
              flex: 3,
              child: WishtickImage(
                url: localPath,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            flex: 2,
            child: Material(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: AppSizes.iconLg,
                          height: AppSizes.iconLg,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add,
                          size: AppSizes.iconLg,
                          color: colors.textMuted,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [TextField.maxLength] keeps the server's cap without drawing a counter the
/// design does not show.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

/// The recipient row — a tap target that reads like the field it replaced.
class _RecipientField extends StatelessWidget {
  const _RecipientField({
    required this.person,
    required this.onTap,
    this.errorText,
    super.key,
  });

  final PersonIdentity? person;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chosen = person;

    return Semantics(
      button: true,
      label: chosen == null ? 'Choose a WishMate' : chosen.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'WishMate *',
            errorText: errorText,
          ),
          child: Row(
            children: [
              if (chosen != null) ...[
                PersonAvatar(
                  person: chosen,
                  diameter: AppSizes.avatarSm,
                  showPresence: false,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  chosen?.name ?? 'Choose',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(
                    color: chosen == null
                        ? colors.textMuted
                        : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary action, which answers a press even when it looks inactive.
///
/// A disabled [ElevatedButton] swallows the tap and says nothing, which on a
/// form this long leaves the user pressing a grey rectangle with no idea which
/// field is holding it. The button keeps its inactive look — it is honest
/// about not being ready — but the press still lands, and [onPressed] is what
/// decides whether to move on or explain.
class _SaveAndContinue extends StatelessWidget {
  const _SaveAndContinue({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            // Null while incomplete, purely so the theme paints it as
            // disabled. The tap is caught above.
            onPressed: enabled ? onPressed : null,
            child: const Text('Save & Continue'),
          ),
        ),
        if (!enabled)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Save & Continue',
              hint: 'Some required fields are still empty',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPressed,
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}
