import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/addresses/data/addresses_repository.dart';
import '../../features/addresses/domain/address.dart';
import 'dev_keys.dart';

/// The address book, against SharedPreferences.
///
/// Mirrors the real service's two invariants exactly — the first address is
/// always the default, and deleting the default promotes a survivor — because
/// a fake that lets the book end up with no default would hide a bug the real
/// backend cannot have.
class DevAddressesRepository implements AddressesRepository {
  DevAddressesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  List<Map<String, dynamic>> _read() =>
      (jsonDecode(_prefs.getString(DevKeys.addresses) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _write(List<Map<String, dynamic>> rows) =>
      _prefs.setString(DevKeys.addresses, jsonEncode(rows));

  /// The same join `address.views.ts` makes, so the dev card reads identically.
  static String _formatted(Map<String, dynamic> row) {
    final street = [
      row['line1'],
      row['locality'],
      row['landmark'],
    ].whereType<String>().where((p) => p.isNotEmpty).join(', ');
    final region = [
      row['city'],
      row['state'],
    ].whereType<String>().where((p) => p.isNotEmpty).join(', ');
    return [
      street,
      '$region ${row['pincode']}'.trim(),
    ].where((p) => p.isNotEmpty).join(', ');
  }

  static Address _toAddress(Map<String, dynamic> row) =>
      Address.fromJson({...row, 'formatted': _formatted(row)});

  @override
  Future<List<Address>> list() async {
    await Future<void>.delayed(_latency);
    final rows = _read()
      ..sort((a, b) {
        final byDefault = ((b['isDefault'] as bool? ?? false) ? 1 : 0)
            .compareTo((a['isDefault'] as bool? ?? false) ? 1 : 0);
        return byDefault != 0
            ? byDefault
            : (b['createdAt'] as String).compareTo(a['createdAt'] as String);
      });
    return rows.map(_toAddress).toList();
  }

  @override
  Future<Address> create({
    required String fullName,
    required String mobile,
    required String line1,
    required String locality,
    required String pincode,
    required String city,
    required String state,
    AddressLabel? label,
    String? altMobile,
    String? email,
    String? landmark,
    bool? isDefault,
  }) async {
    await Future<void>.delayed(_latency);
    final rows = _read();

    final makeDefault = isDefault == true || rows.isEmpty;
    if (makeDefault) {
      for (final row in rows) {
        row['isDefault'] = false;
      }
    }

    final row = <String, dynamic>{
      'id': 'dev-addr-${DateTime.now().microsecondsSinceEpoch}',
      'label': (label ?? AddressLabel.home).wireValue,
      'fullName': fullName,
      'mobile': mobile,
      'altMobile': altMobile,
      'email': email,
      'line1': line1,
      'locality': locality,
      'landmark': landmark,
      'pincode': pincode,
      'city': city,
      'state': state,
      'countryCode': 'IN',
      'isDefault': makeDefault,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _write([...rows, row]);
    return _toAddress(row);
  }

  @override
  Future<Address> update(
    String id, {
    AddressLabel? label,
    String? fullName,
    String? mobile,
    String? altMobile,
    String? email,
    String? line1,
    String? locality,
    String? landmark,
    String? pincode,
    String? city,
    String? state,
    bool? isDefault,
  }) async {
    await Future<void>.delayed(_latency);
    final rows = _read();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index == -1) throw StateError('Address $id not found');

    final row = rows[index];
    if (label != null) row['label'] = label.wireValue;
    if (fullName != null) row['fullName'] = fullName;
    if (mobile != null) row['mobile'] = mobile;
    if (altMobile != null) row['altMobile'] = altMobile;
    if (email != null) row['email'] = email;
    if (line1 != null) row['line1'] = line1;
    if (locality != null) row['locality'] = locality;
    if (landmark != null) row['landmark'] = landmark;
    if (pincode != null) row['pincode'] = pincode;
    if (city != null) row['city'] = city;
    if (state != null) row['state'] = state;

    if (isDefault == true) {
      for (final other in rows) {
        other['isDefault'] = false;
      }
      row['isDefault'] = true;
    } else if (isDefault == false) {
      // Demoting the only address is a no-op, exactly as the service decides.
      row['isDefault'] = rows.length == 1;
    }

    await _write(rows);
    return _toAddress(row);
  }

  @override
  Future<Address> setDefault(String id) => update(id, isDefault: true);

  @override
  Future<void> remove(String id) async {
    final rows = _read();
    final removed = rows.firstWhere(
      (r) => r['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    rows.removeWhere((r) => r['id'] == id);

    if ((removed['isDefault'] as bool? ?? false) && rows.isNotEmpty) {
      rows.sort(
        (a, b) =>
            (b['createdAt'] as String).compareTo(a['createdAt'] as String),
      );
      rows.first['isDefault'] = true;
    }
    await _write(rows);
  }
}
