import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../home/presentation/widgets/occasion_grid.dart';
import '../../wishmates/domain/wishmate.dart';
import '../../wishmates/presentation/wishmates_providers.dart';
import '../domain/wishlist.dart';
import 'cover_crop_screen.dart';
import 'wishlist_detail_controller.dart';
import 'wishlist_suggestions.dart';
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

  /// Where a cover comes from: the gallery, then the cropper. Null if either
  /// step was backed out of.
  ///
  /// A hook rather than a direct call because neither half can run in a widget
  /// test — `ImagePicker` needs a platform gallery, and the cropper needs to
  /// decode a real image — while everything the screen does *with* the bytes
  /// afterwards is exactly what wants testing.
  @visibleForTesting
  static Future<Uint8List?> Function(BuildContext context) chooseCover =
      _cropFromGallery;

  static Future<Uint8List?> _cropFromGallery(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return null;

    // Framed on the device before anything is sent: covers are shown
    // landscape, so what is confirmed here is exactly what gets stored, and
    // there is no full-size original left on the server to crop again.
    final original = await picked.readAsBytes();
    if (!context.mounted) return null;
    return CoverCropScreen.show(context, original);
  }

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

  /// The cover already on the CDN — the one the list being edited was saved
  /// with, or the one this screen uploaded on a save that then failed.
  MediaView? _cover;

  /// A cover chosen but not yet sent anywhere.
  ///
  /// Held on the device until Save: uploading at pick time meant every
  /// abandoned Create Wishlist left an orphaned file on Bunny that nothing
  /// ever pointed at and nothing ever cleaned up.
  ///
  /// Outranks [_cover] wherever both are set — what is in hand is always the
  /// newer choice.
  Uint8List? _coverBytes;

  /// The WishMate picked from the name suggestions, if any.
  ///
  /// Held as the person, not just an id, so the "For Siya" pill can name them
  /// without another lookup. Cleared the moment the name is edited away from
  /// theirs: a list called "Camping gear" that quietly stays linked to Siya is
  /// exactly the kind of stale link nobody notices until it is wrong.
  PersonIdentity? _forMate;

  /// Pending when editing a list that was already for someone: the id is
  /// known at once, the person only once the WishMates have loaded.
  String? _forUserIdToResolve;
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
    _forUserIdToResolve = editing?.forUserId;
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
    final cropped = await CreateWishlistScreen.chooseCover(context);
    if (cropped == null || !mounted) return;
    // [_cover] is left as it was: bytes in hand outrank it everywhere, so a
    // fresh pick replaces the list's old cover — and any copy a failed save
    // already uploaded — without a second field to keep in step.
    setState(() => _coverBytes = cropped);
  }

  /// Sends the held cover to the CDN, and answers the id to save against.
  ///
  /// Null means the upload failed and the error is already on screen; the
  /// wishlist must not be written without its cover. Kept on [_cover] so a
  /// retry after a *save* failure does not upload the same picture twice.
  Future<String?> _uploadCover() async {
    final bytes = _coverBytes;
    if (bytes == null) return _cover?.id;

    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(
            file: XFile.fromData(
              bytes,
              name: 'cover.jpg',
              mimeType: 'image/jpeg',
            ),
            purpose: MediaPurpose.wishlistCover,
          );
      if (mounted) {
        setState(() {
          _cover = media;
          _coverBytes = null;
        });
      }
      return media.id;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return null;
    }
  }

  String? get _titleError {
    if (!_submitted) return null;
    return _title.text.trim().isEmpty ? 'Please enter a name' : null;
  }

  String? get _coverError {
    if (!_submitted) return null;
    return _cover == null && _coverBytes == null
        ? 'Please add a cover image'
        : null;
  }

  String? get _occasionError {
    if (!_submitted) return null;
    return _occasionLabel.text.trim().isEmpty
        ? 'Please choose an occasion'
        : null;
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
        _occasionError != null ||
        _coverError != null ||
        _descriptionError != null ||
        _visibilityError != null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // Only now does the picture leave the device. A cover the reader chose and
    // then walked away from never becomes a file on the CDN.
    final coverMediaId = await _uploadCover();
    if (!mounted) return;
    if (coverMediaId == null) {
      setState(() => _busy = false);
      return;
    }

    final editing = widget.editing;
    // Pops with the new list, so whoever opened this to *get* a wishlist —
    // the event wizard, linking one to the invitation — has it in hand.
    Wishlist? created;
    final bool ok;
    if (editing == null) {
      created = await ref
          .read(wishlistsProvider.notifier)
          .create(
            title: _title.text.trim(),
            description: _description.text.trim(),
            occasionLabel: _occasionLabel.text.trim(),
            visibility: _visibility!,
            coverMediaId: coverMediaId,
            forUserId: _forMate?.userId,
          );
      ok = created != null;
    } else {
      ok = await ref
          .read(wishlistDetailProvider(editing.id).notifier)
          .update(
            title: _title.text.trim(),
            description: _description.text.trim(),
            occasionLabel: _occasionLabel.text.trim(),
            visibility: _visibility!,
            coverMediaId: coverMediaId,
            forUserId: _forMate?.userId,
          );
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(created);
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
                      // Rebuilds the suggestions as they type, and drops a
                      // stale link the moment the name stops being theirs.
                      onChanged: (text) => setState(() {
                        final mate = _forMate;
                        if (mate != null && text.trim() != mate.name) {
                          _forMate = null;
                        }
                      }),
                      decoration: InputDecoration(
                        label: _RequiredLabel('WishMate'),
                        hintText: 'Type a name',
                        errorText: _titleError,
                      ),
                    ),
                    _NameSuggestions(
                      typed: _title.text,
                      linked: _forMate,
                      pendingUserId: _forUserIdToResolve,
                      onPick: (mate) => setState(() {
                        _forMate = mate;
                        _forUserIdToResolve = null;
                        _title.text = mate.name;
                        _title.selection = TextSelection.collapsed(
                          offset: _title.text.length,
                        );
                      }),
                      onResolved: (mate) => setState(() {
                        _forMate = mate;
                        _forUserIdToResolve = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _occasionLabel,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        label: _RequiredLabel('Occasion'),
                        hintText: 'Pick one below, or type your own',
                        errorText: _occasionError,
                      ),
                    ),
                    _OccasionPicker(
                      typed: _occasionLabel.text,
                      onPick: (label) => setState(() {
                        _occasionLabel.text = label;
                        _occasionLabel.selection = TextSelection.collapsed(
                          offset: label.length,
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _RequiredLabel('Cover Image', asField: true),
                    const SizedBox(height: AppSpacing.sm),
                    _CoverImagePicker(
                      cover: _cover,
                      bytes: _coverBytes,
                      onTap: _busy ? null : _pickCover,
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
    required this.bytes,
    required this.onTap,
  });

  final MediaView? cover;

  /// A cover chosen but not yet uploaded. Drawn from memory, so the reader
  /// sees what they cropped without a round trip to a CDN that has never
  /// heard of it.
  final Uint8List? bytes;
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
          child: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: _height,
                  ),
                )
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

/// WishMates whose name matches what has been typed, and the link once picked.
///
/// "Type the name and we suggest from your WishMates": rows under the field,
/// not a dropdown that steals the keyboard. Picking one puts their name in the
/// field and links the list to them, and the rows step aside. Free text stays
/// free — a name that matches nobody is still a fine name.
class _NameSuggestions extends ConsumerWidget {
  const _NameSuggestions({
    required this.typed,
    required this.linked,
    required this.pendingUserId,
    required this.onPick,
    required this.onResolved,
  });

  final String typed;
  final PersonIdentity? linked;
  final String? pendingUserId;
  final ValueChanged<PersonIdentity> onPick;
  final ValueChanged<PersonIdentity> onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mates = ref.watch(wishmatesProvider).value ?? const <Wishmate>[];

    // Editing a list that was already for someone: the id arrived with the
    // list, the person only now. Resolved once, after this frame, so the
    // parent is not asked to rebuild mid-build.
    final pending = pendingUserId;
    if (pending != null && linked == null && mates.isNotEmpty) {
      for (final m in mates) {
        if (m.userId == pending) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onResolved(m));
          break;
        }
      }
    }

    // Nothing once one is picked: their name is in the field, and a chip
    // beside it read as one of several — as though the next tap would add a
    // second WishMate. Editing the name away is what unlinks, which is the
    // same gesture as changing your mind about it.
    if (linked != null) return const SizedBox.shrink();

    final matches = matchingWishmates(mates, typed);
    if (matches.isEmpty) return const SizedBox.shrink();

    return _SuggestionList(
      children: [
        for (final m in matches)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: AppSizes.avatarSm / 2,
              backgroundColor: colors.surface,
              child: Text(
                m.name.characters.first.toUpperCase(),
                style: context.text.bodySmall?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            title: Text(
              m.name,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            onTap: () => onPick(m),
          ),
      ],
    );
  }
}

/// The occasions to choose from, as Home draws them: a photo and a label.
///
/// A grid rather than a list of words, because that is what the picker on Home
/// already is and an occasion is a thing people recognise by its picture. What
/// is typed filters it, so the field still narrows as you go — and a name that
/// matches no tile is still allowed, since the taxonomy is not everybody's
/// list of reasons to give a gift.
///
/// "Custom Events" is deliberately absent: on Home it starts an event, which
/// is an action, not an occasion a wishlist could be for.
class _OccasionPicker extends StatelessWidget {
  const _OccasionPicker({required this.typed, required this.onPick});

  final String typed;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final q = typed.trim().toLowerCase();
    final tiles = kHomeOccasions
        .where((o) => q.isEmpty || o.label.toLowerCase().contains(q))
        .toList();
    if (tiles.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.82,
        children: [
          for (final o in tiles)
            _OccasionTile(
              tile: o,
              // Compared against the field, not against a second piece of
              // state: typing a label by hand and tapping its tile mean the
              // same thing, so they had better look the same.
              selected: o.label.toLowerCase() == q,
              onTap: () => onPick(o.label),
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _OccasionTile extends StatelessWidget {
  const _OccasionTile({
    required this.tile,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final OccasionTile tile;
  final bool selected;
  final VoidCallback onTap;
  final WishtickColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tile.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected ? colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.asset(
                    tile.image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tile.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rows a field suggests, drawn right beneath it.
///
/// A bordered list rather than a strip of chips: it reads as "pick one of
/// these to finish what you typed", which is the promise a suggestion makes.
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
