import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/dev/dev_addresses_repository.dart';
import 'package:wishtick_flutter/features/addresses/domain/address.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DevAddressesRepository> repo() async {
    SharedPreferences.setMockInitialValues({});
    return DevAddressesRepository(await SharedPreferences.getInstance());
  }

  Future<Address> add(
    DevAddressesRepository r, {
    AddressLabel label = AddressLabel.home,
    bool? isDefault,
  }) => r.create(
    label: label,
    fullName: 'Siya',
    mobile: '9890900089',
    line1: 'D-Block',
    locality: 'JP Nagar',
    pincode: '570031',
    city: 'Mysuru',
    state: 'Karnataka',
    isDefault: isDefault,
  );

  test('the first saved address becomes the default', () async {
    final r = await repo();
    final created = await add(r, isDefault: false);

    expect(created.isDefault, isTrue);
    expect(created.countryCode, 'IN');
  });

  test('formats the card line the way the design reads', () async {
    final r = await repo();
    final created = await add(r);
    expect(created.formatted, 'D-Block, JP Nagar, Mysuru, Karnataka 570031');
  });

  test('promoting one demotes the incumbent', () async {
    final r = await repo();
    await add(r);
    final second = await add(r, label: AddressLabel.work);
    expect(second.isDefault, isFalse);

    await r.setDefault(second.id);

    final all = await r.list();
    expect(all.where((a) => a.isDefault), hasLength(1));
    // The default sorts first.
    expect(all.first.label, AddressLabel.work);
  });

  test('will not leave the book with no default', () async {
    final r = await repo();
    final only = await add(r);

    final updated = await r.update(only.id, isDefault: false);

    expect(updated.isDefault, isTrue);
  });

  test('removing the default promotes a survivor', () async {
    final r = await repo();
    final first = await add(r);
    await add(r, label: AddressLabel.work);

    await r.remove(first.id);

    final all = await r.list();
    expect(all, hasLength(1));
    expect(all.single.label, AddressLabel.work);
    expect(all.single.isDefault, isTrue);
  });

  test('survives a restart, so Home still knows where to deliver', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await add(DevAddressesRepository(prefs));

    // A fresh instance over the same prefs is what a relaunch looks like.
    final restarted = await DevAddressesRepository(prefs).list();

    expect(restarted, hasLength(1));
    expect(restarted.single.label, AddressLabel.home);
  });
}
