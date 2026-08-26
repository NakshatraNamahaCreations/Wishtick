import 'package:flutter/foundation.dart';

/// The three options the profile screen offers (Figma `31:608`), matching the
/// backend `Gender` enum.
enum Gender {
  male('male', 'Male'),
  female('female', 'Female'),
  other('other', 'Other');

  const Gender(this.wireValue, this.label);

  /// What the API stores.
  final String wireValue;

  /// What the tile reads.
  final String label;

  static Gender? fromWire(String? value) {
    if (value == null) return null;
    for (final g in Gender.values) {
      if (g.wireValue == value) return g;
    }
    return null;
  }
}

/// One of the bundled illustrated avatars.
///
/// The backend stores only the key (`avatar_07`); the image itself ships with
/// the app, so nothing has to be uploaded or fetched.
@immutable
class BundledAvatar {
  const BundledAvatar(this.index);

  /// 1-based, matching the asset filenames.
  final int index;

  static const count = 20;

  static final all = List<BundledAvatar>.unmodifiable(
    List.generate(count, (i) => BundledAvatar(i + 1)),
  );

  /// What a new profile starts out wearing.
  ///
  /// A real selection, not a placeholder the screen happens to draw. Create
  /// Profile always shows a face, so somebody who leaves it alone has every
  /// reason to think they chose it — and while the draft held null the key was
  /// never sent, so they turned up to everybody else as a bare initial. The
  /// picker opens with this one already ticked, and saving persists it.
  static final defaultChoice = all.first;

  String get key => 'avatar_${index.toString().padLeft(2, '0')}';
  String get asset => 'assets/avatar/${index.toString().padLeft(2, '0')}.png';

  static BundledAvatar? fromKey(String? key) {
    if (key == null) return null;
    final match = RegExp(r'^avatar_(\d{2})$').firstMatch(key);
    if (match == null) return null;
    final index = int.parse(match.group(1)!);
    if (index < 1 || index > count) return null;
    return BundledAvatar(index);
  }

  @override
  bool operator ==(Object other) =>
      other is BundledAvatar && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// What the user has filled in on "Create Your Profile" so far.
@immutable
class ProfileDraft {
  const ProfileDraft({
    this.name = '',
    this.email = '',
    this.dateOfBirth,
    this.gender,
    this.avatar,
    this.photoMediaId,
  });

  final String name;
  final String email;
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// The chosen preset. Mutually exclusive with [photoMediaId] — the backend
  /// clears one when the other is set, so the UI mirrors that, and
  /// [copyWith]'s `clearAvatar` is how an upload from the gallery takes over.
  ///
  /// Null means *deliberately* none, which on this form only happens once a
  /// photo has been picked. A fresh form starts on [BundledAvatar.defaultChoice]
  /// — seeded where the form is created rather than defaulted here, so that
  /// clearing it stays possible.
  final BundledAvatar? avatar;
  final String? photoMediaId;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get hasName => name.trim().isNotEmpty;
  bool get hasValidEmail => _emailPattern.hasMatch(email.trim());

  /// The screen marks name, email, date of birth and gender as required.
  bool get isComplete =>
      hasName && hasValidEmail && dateOfBirth != null && gender != null;

  /// `yyyy-MM-dd`, the date-only format the API expects.
  String? get dateOfBirthIso {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final month = dob.month.toString().padLeft(2, '0');
    final day = dob.day.toString().padLeft(2, '0');
    return '${dob.year}-$month-$day';
  }

  /// `dd/mm/yyyy`, as the field displays it.
  String get dateOfBirthDisplay {
    final dob = dateOfBirth;
    if (dob == null) return '';
    final day = dob.day.toString().padLeft(2, '0');
    final month = dob.month.toString().padLeft(2, '0');
    return '$day/$month/${dob.year}';
  }

  ProfileDraft copyWith({
    String? name,
    String? email,
    DateTime? dateOfBirth,
    Gender? gender,
    BundledAvatar? avatar,
    String? photoMediaId,
    bool clearAvatar = false,
    bool clearPhoto = false,
    bool clearDateOfBirth = false,
  }) {
    return ProfileDraft(
      name: name ?? this.name,
      email: email ?? this.email,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      gender: gender ?? this.gender,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
      photoMediaId: clearPhoto ? null : (photoMediaId ?? this.photoMediaId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileDraft &&
      other.name == name &&
      other.email == email &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.avatar == avatar &&
      other.photoMediaId == photoMediaId;

  @override
  int get hashCode =>
      Object.hash(name, email, dateOfBirth, gender, avatar, photoMediaId);
}
