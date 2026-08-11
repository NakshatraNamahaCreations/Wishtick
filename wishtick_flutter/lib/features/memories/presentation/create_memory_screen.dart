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
  late final _person = TextEditingController(
    text: ref.read(createMemoryProvider).personName,
  );
  late final _description = TextEditingController(
    text: ref.read(createMemoryProvider).description,
  );

  bool _uploadingCover = false;
  String? _coverError;

  @override
  void dispose() {
    _title.dispose();
    _person.dispose();
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
            decoration: const InputDecoration(
              labelText: 'Memory Name *',
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
                child: TextField(
                  controller: _person,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 120,
                  buildCounter: _noCounter,
                  decoration: const InputDecoration(
                    labelText: "Person's Name *",
                    hintText: 'Ananya',
                  ),
                  onChanged: notifier.setPersonName,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: _RelationField(
                  label: state.relationLabel,
                  onTap: _pickRelation,
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
            decoration: const InputDecoration(
              labelText: 'Description *',
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.step1Complete
                  ? () => context.push<void>(AppRoutes.createMemoryUnlock)
                  : null,
              child: const Text('Save & Continue'),
            ),
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
  const _RelationField({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Relation *'),
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
