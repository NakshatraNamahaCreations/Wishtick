import 'package:flutter/foundation.dart';

/// The three chips under "Save address as" (`324:1340`).
enum AddressLabel {
  home('home', 'Home'),
  work('work', 'Work'),
  other('other', 'Other');

  const AddressLabel(this.wireValue, this.display);

  final String wireValue;

  /// What a card shows.
  ///
  /// Named `display`, not `label`: an [Address] already has a `label` field
  /// holding this enum, so `address.label` reads like the text and
  /// interpolating it silently yields "AddressLabel.home" — which is exactly
  /// how it reached Home's header on a real device. `address.label.display`
  /// cannot be mistaken for the enum.
  final String display;

  static AddressLabel fromWire(String? value) => AddressLabel.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => home,
  );
}

/// One saved delivery address (`GET /me/addresses`).
///
/// The field names track the form in `324:1340` rather than a generic postal
/// schema: the design asks for "Flat No / Building Name" and "Locality / Area"
/// as separate lines, and a landmark, which a plain `line1`/`line2` pair loses.
@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.fullName,
    required this.mobile,
    required this.altMobile,
    required this.email,
    required this.line1,
    required this.locality,
    required this.landmark,
    required this.pincode,
    required this.city,
    required this.state,
    required this.countryCode,
    required this.isDefault,
    required this.formatted,
  });

  final String id;
  final AddressLabel label;

  // ── Contact information ──────────────────────────────────────────────────

  final String fullName;
  final String mobile;
  final String? altMobile;
  final String? email;

  // ── Address information ──────────────────────────────────────────────────

  /// "Flat No / Building Name".
  final String line1;

  /// "Locality / Area".
  final String locality;
  final String? landmark;
  final String pincode;
  final String city;
  final String state;
  final String countryCode;

  /// Exactly one saved address carries this; the backend holds the invariant.
  final bool isDefault;

  /// The card's middle block, joined server-side.
  ///
  /// Comes down the wire rather than being rebuilt here so the address book,
  /// the delivery picker and any future export all read identically — see
  /// `address.views.ts`.
  final String formatted;

  /// The single line Home's "Where To Deliver?" header shows.
  String get shortLine => '$city $pincode';

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as String,
    label: AddressLabel.fromWire(json['label'] as String?),
    fullName: json['fullName'] as String,
    mobile: json['mobile'] as String,
    altMobile: json['altMobile'] as String?,
    email: json['email'] as String?,
    line1: json['line1'] as String,
    locality: json['locality'] as String,
    landmark: json['landmark'] as String?,
    pincode: json['pincode'] as String,
    city: json['city'] as String,
    state: json['state'] as String,
    countryCode: json['countryCode'] as String? ?? 'IN',
    isDefault: json['isDefault'] as bool? ?? false,
    formatted: json['formatted'] as String? ?? '',
  );
}
