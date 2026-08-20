import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/wishlist.dart';
import 'wishlist_detail_controller.dart';
import 'wishlists_controller.dart';

/// Figma `280:476` — Wishlist Name, Occasion, Cover Image, Description,
/// Privacy. The mock also shows a "Deliver To" affordance, but no address
/// concept exists anywhere in the backend yet, so it is left out entirely
/// rather than shipping a control that cannot do anything.
///
/// Doubles as the edit screen (the design has no separate edit mock) — pass
/// [editing] to prefill the form and save via `PATCH` instead of `POST`.
class CreateWishlistScreen extends ConsumerStatefulWidget {
  const CreateWishlistScreen({this.editing, super.key});

  final Wishlist? editing;

  @override
  ConsumerState<CreateWishlistScreen> createState() =>
      _CreateWishlistScreenState();
}

class _CreateWishlistScreenState extends ConsumerState<CreateWishlistScreen> {
  late final _title = TextEditingController(text: widget.editing?.title);
  late final _occasionLabel = TextEditingController(
    text: widget.editing?.occasionLabel,
  );
  late final _description = TextEditingController(
    text: widget.editing?.description,
  );

  MediaView? _cover;
  bool _uploadingCover = false;
  WishlistVisibility? _visibility;

  bool _submitted = false;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _visibility = editing?.visibility;
    final coverUrl = editing?.coverUrl;
    if (coverUrl != null) {
      _cover = MediaView(
        id: coverUrl,
        url: coverUrl,
        purpose: MediaPurpose.wishlistCover.wireValue,
        contentType: null,
        sizeBytes: null,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _occasionLabel.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _uploadingCover = true);
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(file: picked, purpose: MediaPurpose.wishlistCover);
      if (!mounted) return;
      setState(() {
        _cover = media;
        _uploadingCover = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        _error = e.message;
      });
    }
  }

  String? get _titleError {
    if (!_submitted) return null;
    return _title.text.trim().isEmpty ? 'Please enter a wishlist name' : null;
  }

  String? get _coverError {
    if (!_submitted) return null;
    return _cover == null ? 'Please add a cover image' : null;
  }

  String? get _descriptionError {
    if (!_submitted) return null;
    return _description.text.trim().isEmpty
        ? 'Please add a short description'
        : null;
  }

  String? get _visibilityError {
    if (!_submitted) return null;
    return _visibility == null ? 'Please choose who can see this' : null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_titleError != null ||
        _coverError != null ||
        _descriptionError != null ||
        _visibilityError != null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final editing = widget.editing;
    final ok = editing == null
        ? await ref
              .read(wishlistsProvider.notifier)
              .create(
                title: _title.text.trim(),
                description: _description.text.trim(),
                occasionLabel: _occasionLabel.text.trim().isEmpty
                    ? null
                    : _occasionLabel.text.trim(),
                visibility: _visibility!,
                coverMediaId: _cover!.id,
              )
        : await ref
              .read(wishlistDetailProvider(editing.id).notifier)
              .update(
                title: _title.text.trim(),
                description: _description.text.trim(),
                occasionLabel: _occasionLabel.text.trim().isEmpty
                    ? null
                    : _occasionLabel.text.trim(),
                visibility: _visibility!,
                coverMediaId: _cover!.id,
              );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = editing == null
            ? ref.read(wishlistsProvider).error
            : ref.read(wishlistDetailProvider(editing.id)).error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Wishlist' : 'Create Wishlist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      WishtickErrorText(_error!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        label: _RequiredLabel('Wishlist Name'),
                        hintText: 'Enter Wishlist Name',
                        errorText: _titleError,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _occasionLabel,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Occasion (Optional)',
                        hintText: 'Enter Occasion name',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _RequiredLabel('Cover Image', asField: true),
                    const SizedBox(height: AppSpacing.sm),
                    _CoverImagePicker(
                      cover: _cover,
                      busy: _uploadingCover,
                      onTap: _uploadingCover ? null : _pickCover,
                    ),
                    if (_coverError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _coverError!,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _description,
                      maxLines: 4,
                      maxLength: 40,
                      decoration: InputDecoration(
                        label: _RequiredLabel('Description'),
                        hintText: 'e.g. A few special things for Ananya',
                        errorText: _descriptionError,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _RequiredLabel('Privacy', asField: true),
                    const SizedBox(height: AppSpacing.md),
                    for (final option in const [
                      (
                        WishlistVisibility.public,
                        'Public',
                        'Anyone with link can view',
                      ),
                      (
                        WishlistVisibility.private,
                        'Private',
                        'Only invited people can view',
                      ),
                      (
                        WishlistVisibility.eventOnly,
                        'Event Only',
                        'Only event invitees can view.',
                      ),
                    ]) ...[
                      _PrivacyOption(
                        title: option.$2,
                        subtitle: option.$3,
                        selected: _visibility == option.$1,
                        onTap: () => setState(() => _visibility = option.$1),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_visibilityError != null)
                      Text(
                        _visibilityError!,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? SizedBox(
                          width: AppSizes.iconMd,
                          height: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Save Wishlist'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label with a red required asterisk — used both as an [InputDecoration]
/// label and as a standalone section heading (`asField: true` matches the
/// bold field-label weight the theme's [TextFormField] labels use).
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text, {this.asField = false});

  final String text;
  final bool asField;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = asField
        ? context.text.titleSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          )
        : context.text.bodyMedium?.copyWith(color: colors.textMuted);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          TextSpan(
            text: ' *',
            style: TextStyle(color: colors.danger),
          ),
        ],
      ),
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({
    required this.cover,
    required this.busy,
    required this.onTap,
  });

  final MediaView? cover;
  final bool busy;
  final VoidCallback? onTap;

  static const _height = 160.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: busy
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : cover != null
              ? WishtickImage(
                  url: cover!.url,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: colors.textMuted,
                        size: AppSizes.iconLg,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '+ Add Cover Image',
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
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

  static const _size = 22.0;
  static const _dotSize = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.primary : colors.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              ),
            )
          : null,
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _RadioDot(selected: selected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
