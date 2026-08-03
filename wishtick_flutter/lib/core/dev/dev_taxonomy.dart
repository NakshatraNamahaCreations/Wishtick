import '../../features/onboarding/domain/onboarding_options.dart';

/// The option catalogue the fake backend serves.
///
/// Mirrors `wishtick_backend/src/modules/taxonomy/taxonomy.seed.ts` so the
/// onboarding screens populate exactly as they will against the real API —
/// same keys, labels and hexes. Dev-only scaffolding: when the backend is
/// reachable this file is never touched, and it is tree-shaken from release
/// builds along with the rest of [DevMode].
///
/// If the seed changes, change this too — or accept that the fake and the real
/// backend disagree.
abstract final class DevTaxonomy {
  static TaxonomyOption _o(
    String key,
    String label, [
    Map<String, String>? m,
  ]) => TaxonomyOption(key: key, label: label, meta: m);

  static List<TaxonomyOption> _interests(
    String category,
    String prefix,
    List<(String, String)> entries,
  ) => [
    for (final (key, label) in entries)
      _o('${prefix}_$key', label, {'category': category}),
  ];

  static List<TaxonomyOption> _colors(
    String group,
    String groupLabel,
    List<(String, String, String)> entries,
  ) => [
    for (final (key, label, hex) in entries)
      _o('${group}_$key', label, {
        'hex': hex,
        'group': group,
        'groupLabel': groupLabel,
      }),
  ];

  static OnboardingOptions build() => OnboardingOptions(
    interestCategories: [
      _o('fashion', 'Fashion & Personal Style'),
      _o('technology', 'Technology & Gadgets'),
      _o('home_living', 'Home & Living'),
      _o('health_fitness', 'Health & Fitness'),
      _o('travel', 'Travel & Experiences'),
      _o('entertainment', 'Entertainment'),
      _o('hobbies', 'Hobbies & Creativity'),
      _o('kids_family', 'Kids & family'),
      _o('automotive', 'Automotive'),
      _o('sustainable', 'Sustainable Living'),
      _o('food_beverages', 'Food & Beverages'),
      _o('other', 'Other'),
    ],
    interests: [
      ..._interests('fashion', 'fashion', [
        ('clothing', 'Clothing'),
        ('shoes', 'Shoes'),
        ('bags_wallets', 'Bags & Wallets'),
        ('watches', 'Watches'),
        ('jewellery', 'Jewellery'),
        ('accessories', 'Accessories'),
        ('eye_wear', 'Eye Wear'),
        ('fragrances', 'Fragrances'),
        ('beauty_makeup', 'Beauty & Makeup'),
        ('grooming', 'Grooming'),
        ('skincare', 'Skincare'),
      ]),
      ..._interests('technology', 'tech', [
        ('smartphones', 'Smartphones'),
        ('computers', 'Computers'),
        ('laptops_tablets', 'Laptops & Tablets'),
        ('audio_devices', 'Audio devices'),
        ('gaming', 'Gaming'),
        ('smart_home', 'Smart Home'),
        ('wearables', 'Wearables'),
        ('camera_photography', 'Camera & Photography'),
        ('accessories', 'Tech Accessories'),
      ]),
      ..._interests('home_living', 'home', [
        ('decor', 'Home decor'),
        ('furniture', 'Furniture'),
        ('kitchen_dining', 'Kitchen & Dining'),
        ('appliances', 'Home Appliances'),
        ('bedding_bath', 'Bedding & Bath'),
        ('lighting', 'Lighting'),
        ('gardening', 'Gardening'),
        ('improvement', 'Home Improvement'),
      ]),
      ..._interests('health_fitness', 'health', [
        ('equipments', 'Equipments'),
        ('sports_gear', 'Sports Gear'),
        ('yoga_meditation', 'Yoga & Meditation'),
        ('nutrition', 'Nutrition'),
        ('outdoor_activities', 'Outdoor Activities'),
        ('cycling', 'Cycling'),
        ('running', 'Running'),
      ]),
      ..._interests('travel', 'travel', [
        ('adventure_outdoor', 'Adventure & Outdoor Activites'),
        ('road_trips', 'Road Trips'),
        ('luxury_leisure', 'Luxury & Liesure Travel'),
        ('accessories', 'Travel Accessories'),
        ('spa_wellness', 'Spa & Wellness'),
        ('fine_dining', 'Fine Dining'),
        ('coffee_dates', 'Coffee dates'),
        ('concerts_live', 'Concert & Live Events'),
        ('movie_theatre', 'Movie & Theatre'),
        ('workshops_classes', 'Workshops & Classes'),
      ]),
      ..._interests('entertainment', 'ent', [
        ('books', 'Books'),
        ('movies_tv_ott', 'Movies & TV & OTT'),
        ('music', 'Music'),
        ('gaming', 'Gaming'),
      ]),
      ..._interests('hobbies', 'hobby', [
        ('art_craft', 'Art & Craft'),
        ('music_instruments', 'Music Instruments'),
        ('pottery', 'Pottery'),
        ('painting', 'Painting'),
      ]),
      ..._interests('kids_family', 'kids', [
        ('baby_products', 'Baby Products'),
        ('toys', 'Toys'),
        ('family_activities', 'Family Activities'),
        ('pet_care', 'Pet Care'),
      ]),
      ..._interests('automotive', 'auto', [
        ('cars', 'Cars'),
        ('motorcycles', 'Motorcycles'),
        ('car_accessories', 'Car Accessories'),
      ]),
      ..._interests('sustainable', 'sus', [
        ('eco_friendly', 'Eco-Friendly Products'),
        ('organic_living', 'Organic Living'),
        ('reusable', 'Reusable Products'),
        ('fashion', 'Sustainable Fashion'),
      ]),
      ..._interests('food_beverages', 'food', [
        ('chocolates_sweets', 'Chocolates & Sweets'),
        ('cakes_desserts', 'Cakes & Deserts'),
        ('beverages', 'Beverages'),
        ('dining_experiences', 'Dining & Restaurant Experiences'),
      ]),
      ..._interests('other', 'other', [
        ('diy_crafts', 'DIY Crafts'),
        ('baking', 'Baking'),
        ('astronomy', 'Astronomy'),
        ('poetry', 'Poetry'),
        ('anime', 'Anime'),
        ('pets', 'Pets'),
      ]),
    ],
    colors: [
      ..._colors('neutral', 'Neutrals & Slate', [
        ('white', 'White', '#FFFFFF'),
        ('beige', 'Beige', '#F9F0E7'),
        ('light_grey', 'Light Grey', '#DEE1E1'),
        ('slate', 'Slate', '#727C8F'),
        ('black', 'Black', '#161616'),
      ]),
      ..._colors('earth', 'Earth Tones', [
        ('cocoa', 'Cocoa', '#8A492B'),
        ('terracotta', 'Terracotta', '#D86F42'),
        ('mocha', 'Mocha', '#AB907F'),
        ('sand', 'Sand', '#E8D2AE'),
        ('olive', 'Olive', '#828050'),
      ]),
      ..._colors('pastel', 'Pastels', [
        ('blush', 'Blush', '#FDB8CA'),
        ('peach', 'Peach', '#FEC1A5'),
        ('lemon', 'Lemon', '#FEEC9F'),
        ('mint', 'Mint', '#ACEBD0'),
        ('lavender', 'Lavender', '#C5BCF5'),
      ]),
      ..._colors('blue', 'Blues', [
        ('navy', 'Navy', '#0C327E'),
        ('royal', 'Royal Blue', '#156BF2'),
        ('sky', 'Sky Blue', '#A7DEFD'),
        ('teal', 'Teal Blue', '#367588'),
        ('periwinkle', 'Peri winkle', '#AEB6E8'),
      ]),
      ..._colors('green', 'Greens', [
        ('forest', 'Forest', '#025733'),
        ('emerald', 'Emerald', '#01AE6F'),
        ('sage', 'Sage', '#A7C3AA'),
        ('mint', 'Mint', '#A9EACE'),
        ('lime', 'Lime', '#F4FF80'),
      ]),
      ..._colors('red', 'Red & Pinks', [
        ('cherry', 'Cherry', '#B71B3D'),
        ('ruby', 'Ruby', '#D81F2C'),
        ('coral', 'Coral', '#FF7B5C'),
        ('rose', 'Rose', '#F4B6C2'),
        ('hot_pink', 'Hot Pink', '#E94E85'),
      ]),
      ..._colors('orange', 'Oranges & Yellows', [
        ('orange', 'Orange', '#FF7300'),
        ('tangerine', 'Tangerine', '#FF8C0A'),
        ('amber', 'Amber', '#F3AB4A'),
        ('yellow', 'Yellow', '#FFD31A'),
        ('lemon', 'Lemon', '#FFE97A'),
      ]),
      ..._colors('purple', 'Purple & Violet', [
        ('plum', 'Plum', '#5B1A6E'),
        ('violet', 'Violet', '#7C6BE6'),
        ('lavender', 'Lavender', '#B7ADF2'),
        ('lilac', 'Lilac', '#D8B6F2'),
        ('orchid', 'Orchid', '#DB7DD9'),
      ]),
    ],
    clothingSizes: [
      _o('xxs', 'XXS'),
      _o('xs', 'XS'),
      _o('s', 'S'),
      _o('m', 'M'),
      _o('l', 'L'),
      _o('xl', 'XL'),
      _o('xxl', 'XXL'),
      _o('xxxl', '3XL'),
    ],
    shoeSizes: [
      for (final n in [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
        _o('uk_$n', 'UK $n', {'system': 'uk'}),
      for (final n in [4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
        _o('us_$n', 'US $n', {'system': 'us'}),
      for (final n in [36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47])
        _o('eu_$n', 'EU $n', {'system': 'eu'}),
    ],
    fitPreferences: [
      _o('slim', 'Slim'),
      _o('regular', 'Regular'),
      _o('relaxed', 'Relaxed'),
      _o('oversized', 'Oversized'),
    ],
    occasions: [
      _o('birthday', 'Birthday'),
      _o('anniversary', 'Anniversary'),
      _o('wedding', 'Wedding'),
      _o('baby_shower', 'Baby Shower'),
      _o('housewarming', 'Housewarming'),
      _o('graduation', 'Graduation'),
      _o('festival', 'Festival'),
      _o('retirement', 'Retirement'),
      _o('engagement', 'Engagement'),
      _o('just_because', 'Just Because'),
      _o('special_moments', 'Special Moments'),
    ],
  );
}
