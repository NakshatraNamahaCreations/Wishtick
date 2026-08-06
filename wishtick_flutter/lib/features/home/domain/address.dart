import 'package:flutter/foundation.dart';

/// One saved delivery address (`GET /me/addresses`).
@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    required this.isDefault,
  });

  final String id;

  /// What the user calls it — "Home", "Work".
  final String label;
  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final String country;

  /// Exactly one saved address carries this; the backend holds the invariant.
  final bool isDefault;

  /// The single line Home's "Where To Deliver?" header shows.
  String get shortLine => '$city $pincode';

  /// The full address as the picker lists it, blank parts omitted.
  String get formatted => [
    line1,
    ?line2,
    city,
    state,
    pincode,
  ].where((p) => p.isNotEmpty).join(', ');

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as String,
    label: json['label'] as String,
    recipientName: json['recipientName'] as String,
    phone: json['phone'] as String,
    line1: json['line1'] as String,
    line2: json['line2'] as String?,
    city: json['city'] as String,
    state: json['state'] as String,
    pincode: json['pincode'] as String,
    country: json['country'] as String? ?? 'India',
    isDefault: json['isDefault'] as bool? ?? false,
  );
}
