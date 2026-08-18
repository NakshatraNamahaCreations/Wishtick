import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/addresses/data/addresses_repository.dart';
import 'package:wishtick_flutter/features/addresses/domain/address.dart';
import 'package:wishtick_flutter/features/discover/data/discover_repository.dart';
import 'package:wishtick_flutter/features/discover/domain/discover_feed.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/home/domain/upcoming_occasion.dart';
import 'package:wishtick_flutter/features/home/domain/wishtick_event.dart';

Address buildAddress({
  String id = 'addr_1',
  AddressLabel label = AddressLabel.home,
  String city = 'Mysuru',
  String pincode = '570031',
  bool isDefault = true,
}) => Address(
  id: id,
  label: label,
  fullName: 'Ananya Sharma',
  mobile: '+919876543210',
  altMobile: null,
  email: null,
  line1: 'D-Block',
  locality: 'JP Nagar',
  landmark: null,
  pincode: pincode,
  city: city,
  state: 'Karnataka',
  countryCode: 'IN',
  isDefault: isDefault,
  formatted: 'D-Block, JP Nagar, $city, Karnataka $pincode',
);

WishtickEvent buildEvent({
  String id = 'ev_1',
  String title = "Siya's Birthday",
  int daysFromNow = 3,
  bool isHosting = false,
}) => WishtickEvent(
  id: id,
  title: title,
  type: EventType.birthday,
  startsAt: DateTime.now().add(Duration(days: daysFromNow)),
  timezone: 'Asia/Kolkata',
  coverUrl: null,
  isHosting: isHosting,
);

GroupGift buildGroupGift({
  String id = 'gg_1',
  GroupGiftStatus status = GroupGiftStatus.open,
  int target = 1600000,
  int collected = 1440000,
  int percentFunded = 90,
}) => GroupGift(
  id: id,
  itemId: 'item_1',
  wishlistId: 'wl_1',
  status: status,
  title: "Siya's birthday gift",
  hostId: 'dev-host-1',
  createdAt: DateTime(2026, 8, 1),
  targetAmountMinor: target,
  collectedAmountMinor: collected,
  currency: 'INR',
  percentFunded: percentFunded,
  contributorCount: 6,
  deadline: DateTime.now().add(const Duration(days: 3)),
  myContributionMinor: 0,
);

UpcomingOccasion buildOccasion({
  String id = 'date_1',
  String personName = 'Siya',
  int daysAway = 3,
}) => UpcomingOccasion(
  id: id,
  personName: personName,
  relation: 'Best Friend',
  occasionKey: 'birthday',
  date: '1999-08-07',
  nextOccurrence: DateTime.now().add(Duration(days: daysAway)),
  daysAway: daysAway,
  turningAge: 27,
);

/// Scriptable stand-in for Home's reads. Each rail can be failed on its own,
/// which is what lets a test prove one dead rail does not blank the screen.
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({
    List<WishtickEvent>? events,
    List<GroupGift>? groupGifts,
    List<UpcomingOccasion>? occasions,
  }) : events = events ?? [],
       groupGifts = groupGifts ?? [],
       occasions = occasions ?? [];

  final List<WishtickEvent> events;
  final List<GroupGift> groupGifts;
  final List<UpcomingOccasion> occasions;

  ApiException? eventFailure;
  ApiException? groupGiftFailure;
  ApiException? occasionFailure;

  @override
  Future<List<UpcomingOccasion>> upcomingOccasions({
    int withinDays = 30,
  }) async {
    final f = occasionFailure;
    if (f != null) throw f;
    return occasions.where((o) => o.daysAway <= withinDays).toList();
  }

  @override
  Future<List<WishtickEvent>> upcomingEvents({int withinDays = 30}) async {
    final f = eventFailure;
    if (f != null) throw f;
    return events.where((e) => e.daysAway() <= withinDays).toList();
  }

  @override
  Future<List<GroupGift>> myGroupGifts({int limit = 10}) async {
    final f = groupGiftFailure;
    if (f != null) throw f;
    return groupGifts.take(limit).toList();
  }
}

/// Scriptable stand-in for the Discover feed.
class FakeDiscoverRepository implements DiscoverRepository {
  FakeDiscoverRepository({this.feedResult});

  DiscoverFeed? feedResult;
  ApiException? failure;

  int feedCalls = 0;
  final occasionShelfCalls = <String>[];

  @override
  Future<DiscoverFeed> feed() async {
    feedCalls++;
    final f = failure;
    if (f != null) throw f;
    return feedResult ?? const DiscoverFeed(sections: []);
  }

  @override
  Future<DiscoverSection> occasionShelf(String occasionKey) async {
    occasionShelfCalls.add(occasionKey);
    final f = failure;
    if (f != null) throw f;
    return DiscoverSection(
      kind: DiscoverSectionKind.personOccasion,
      title: 'Gifts for $occasionKey',
      subtitle: null,
      person: null,
      items: const [],
      exploreQuery: const DiscoverExploreQuery(
        category: 'electronics',
        minPriceMinor: null,
        maxPriceMinor: null,
      ),
    );
  }
}

/// Scriptable stand-in for the address book.
///
/// Split from [FakeHomeRepository] when the address book became a Profile
/// screen with its own repository — Home only reads the list now.
class FakeAddressesRepository implements AddressesRepository {
  FakeAddressesRepository({List<Address>? addresses})
    : addresses = addresses ?? [];

  final List<Address> addresses;
  ApiException? failure;
  int listCalls = 0;

  @override
  Future<List<Address>> list() async {
    listCalls++;
    final f = failure;
    if (f != null) throw f;
    return List.of(addresses);
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
    final f = failure;
    if (f != null) throw f;
    final created = buildAddress(
      id: 'addr_${addresses.length + 1}',
      label: label ?? AddressLabel.home,
      city: city,
      pincode: pincode,
      isDefault: isDefault == true || addresses.isEmpty,
    );
    addresses.add(created);
    return created;
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
    final f = failure;
    if (f != null) throw f;
    final index = addresses.indexWhere((a) => a.id == id);
    final updated = buildAddress(
      id: id,
      label: label ?? addresses[index].label,
      city: city ?? addresses[index].city,
      pincode: pincode ?? addresses[index].pincode,
      isDefault: isDefault ?? addresses[index].isDefault,
    );
    addresses[index] = updated;
    return updated;
  }

  @override
  Future<Address> setDefault(String id) => update(id, isDefault: true);

  @override
  Future<void> remove(String id) async {
    final f = failure;
    if (f != null) throw f;
    addresses.removeWhere((a) => a.id == id);
  }
}
