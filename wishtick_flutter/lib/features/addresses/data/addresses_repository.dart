import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/address.dart';

/// The address book (`324:1295`, `324:1340`).
///
/// Its own repository rather than a corner of `HomeRepository`: the book is a
/// Profile screen with its own create/edit/delete/set-default surface, and Home
/// only ever reads the list.
class AddressesRepository {
  AddressesRepository(this._api);

  final ApiClient _api;

  /// The default first, then newest.
  Future<List<Address>> list() async {
    final json = await _api.get<List<dynamic>>('/me/addresses');
    return json
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves a new address. The first one saved becomes the default whatever
  /// [isDefault] says — the server will not leave the book without one.
  ///
  /// Throws [ApiException] with `ADDRESS_LIMIT_REACHED` (409) past 25 entries.
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
    final json = await _api.post<Map<String, dynamic>>(
      '/me/addresses',
      body: {
        'fullName': fullName,
        'mobile': mobile,
        'line1': line1,
        'locality': locality,
        'pincode': pincode,
        'city': city,
        'state': state,
        'label': ?label?.wireValue,
        'altMobile': ?altMobile,
        'email': ?email,
        'landmark': ?landmark,
        'isDefault': ?isDefault,
      },
    );
    return Address.fromJson(json);
  }

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
    final json = await _api.patch<Map<String, dynamic>>(
      '/me/addresses/$id',
      body: {
        'label': ?label?.wireValue,
        'fullName': ?fullName,
        'mobile': ?mobile,
        'altMobile': ?altMobile,
        'email': ?email,
        'line1': ?line1,
        'locality': ?locality,
        'landmark': ?landmark,
        'pincode': ?pincode,
        'city': ?city,
        'state': ?state,
        'isDefault': ?isDefault,
      },
    );
    return Address.fromJson(json);
  }

  Future<Address> setDefault(String id) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/me/addresses/$id/default',
    );
    return Address.fromJson(json);
  }

  /// Deletes it. If it was the default the newest survivor takes over, so the
  /// caller should refresh the list rather than patching it in place.
  Future<void> remove(String id) => _api.delete<void>('/me/addresses/$id');
}

final addressesRepositoryProvider = Provider<AddressesRepository>((ref) {
  return AddressesRepository(ref.watch(apiClientProvider));
});
