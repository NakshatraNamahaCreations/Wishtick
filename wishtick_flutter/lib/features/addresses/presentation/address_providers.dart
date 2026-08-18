import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/addresses_repository.dart';
import '../domain/address.dart';

/// The address book.
///
/// Not `autoDispose`: Home's header, the delivery picker and the Profile
/// address book all read the same list, and dropping it between them would
/// refetch on every navigation.
final addressBookProvider = FutureProvider<List<Address>>((ref) {
  return ref.watch(addressesRepositoryProvider).list();
});

/// The address an order defaults to — the first row, since the list comes down
/// with the default pinned to the top.
final defaultAddressProvider = Provider<Address?>((ref) {
  final book = ref.watch(addressBookProvider).value;
  return (book == null || book.isEmpty) ? null : book.first;
});
