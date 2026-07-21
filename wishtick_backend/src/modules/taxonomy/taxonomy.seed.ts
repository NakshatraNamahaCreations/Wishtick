import { TaxonomyKind } from './taxonomy.types';

export interface SeedTerm {
  kind: TaxonomyKind;
  key: string;
  label: string;
  meta?: Record<string, string>;
  sortOrder: number;
}

const rows = (
  kind: TaxonomyKind,
  entries: [key: string, label: string, meta?: Record<string, string>][],
): SeedTerm[] =>
  entries.map(([key, label, meta], i) => ({ kind, key, label, meta, sortOrder: i * 10 }));

/**
 * The launch taxonomy. Sprint 11 gives admins CRUD over this; the seed only
 * establishes the starting set, and re-running it never clobbers admin edits
 * (see the upsert in the seed migration).
 */
export const TAXONOMY_SEED: SeedTerm[] = [
  ...rows(TaxonomyKind.INTEREST, [
    ['music', 'Music'],
    ['travel', 'Travel'],
    ['reading', 'Reading'],
    ['gaming', 'Gaming'],
    ['cooking', 'Cooking'],
    ['fitness', 'Fitness'],
    ['photography', 'Photography'],
    ['art', 'Art & Design'],
    ['technology', 'Technology'],
    ['fashion', 'Fashion'],
    ['movies', 'Movies & TV'],
    ['sports', 'Sports'],
    ['gardening', 'Gardening'],
    ['pets', 'Pets'],
    ['crafts', 'DIY & Crafts'],
    ['outdoors', 'Outdoors & Hiking'],
    ['wellness', 'Wellness & Self-care'],
    ['collecting', 'Collecting'],
  ]),

  // `hex` lets clients render a swatch without shipping its own colour table.
  ...rows(TaxonomyKind.COLOR, [
    ['black', 'Black', { hex: '#000000' }],
    ['white', 'White', { hex: '#FFFFFF' }],
    ['red', 'Red', { hex: '#E53935' }],
    ['pink', 'Pink', { hex: '#EC407A' }],
    ['purple', 'Purple', { hex: '#8E24AA' }],
    ['blue', 'Blue', { hex: '#1E88E5' }],
    ['teal', 'Teal', { hex: '#00897B' }],
    ['green', 'Green', { hex: '#43A047' }],
    ['yellow', 'Yellow', { hex: '#FDD835' }],
    ['orange', 'Orange', { hex: '#FB8C00' }],
    ['brown', 'Brown', { hex: '#6D4C41' }],
    ['grey', 'Grey', { hex: '#757575' }],
    ['beige', 'Beige', { hex: '#D7CCC8' }],
    ['gold', 'Gold', { hex: '#C9A227' }],
    ['silver', 'Silver', { hex: '#B0BEC5' }],
  ]),

  ...rows(TaxonomyKind.CLOTHING_SIZE, [
    ['xxs', 'XXS', { system: 'alpha' }],
    ['xs', 'XS', { system: 'alpha' }],
    ['s', 'S', { system: 'alpha' }],
    ['m', 'M', { system: 'alpha' }],
    ['l', 'L', { system: 'alpha' }],
    ['xl', 'XL', { system: 'alpha' }],
    ['xxl', 'XXL', { system: 'alpha' }],
    ['xxxl', '3XL', { system: 'alpha' }],
    ['prefer_not_to_say', 'Prefer not to say'],
  ]),

  // Shoe size is optional in the scope, so it carries an explicit opt-out.
  ...rows(TaxonomyKind.SHOE_SIZE, [
    ['uk_3', 'UK 3', { system: 'uk' }],
    ['uk_4', 'UK 4', { system: 'uk' }],
    ['uk_5', 'UK 5', { system: 'uk' }],
    ['uk_6', 'UK 6', { system: 'uk' }],
    ['uk_7', 'UK 7', { system: 'uk' }],
    ['uk_8', 'UK 8', { system: 'uk' }],
    ['uk_9', 'UK 9', { system: 'uk' }],
    ['uk_10', 'UK 10', { system: 'uk' }],
    ['uk_11', 'UK 11', { system: 'uk' }],
    ['uk_12', 'UK 12', { system: 'uk' }],
    ['prefer_not_to_say', 'Prefer not to say'],
  ]),

  ...rows(TaxonomyKind.GIFT_CATEGORY, [
    ['books', 'Books'],
    ['electronics', 'Electronics'],
    ['fashion', 'Fashion & Accessories'],
    ['beauty', 'Beauty & Grooming'],
    ['home', 'Home & Living'],
    ['kitchen', 'Kitchen & Dining'],
    ['toys', 'Toys & Games'],
    ['sports_gear', 'Sports & Fitness'],
    ['experiences', 'Experiences'],
    ['handmade', 'Handmade & Personalised'],
    ['jewellery', 'Jewellery'],
    ['stationery', 'Stationery'],
    ['gift_cards', 'Gift Cards'],
    ['food_drink', 'Food & Drink'],
  ]),

  ...rows(TaxonomyKind.LIFESTYLE, [
    ['minimalist', 'Minimalist'],
    ['eco_conscious', 'Eco-conscious'],
    ['luxury', 'Luxury'],
    ['practical', 'Practical'],
    ['trendy', 'Trendy'],
    ['homebody', 'Homebody'],
    ['adventurer', 'Adventurer'],
    ['foodie', 'Foodie'],
    ['tech_savvy', 'Tech-savvy'],
    ['vegan', 'Vegan'],
    ['pet_parent', 'Pet parent'],
    ['new_parent', 'New parent'],
  ]),

  ...rows(TaxonomyKind.OCCASION, [
    ['birthday', 'Birthday'],
    ['anniversary', 'Anniversary'],
    ['wedding', 'Wedding'],
    ['baby_shower', 'Baby Shower'],
    ['housewarming', 'Housewarming'],
    ['graduation', 'Graduation'],
    ['festival', 'Festival'],
    ['retirement', 'Retirement'],
    ['engagement', 'Engagement'],
    ['just_because', 'Just Because'],
  ]),

  // Mirrors Event.type in Sprint 5. Kept in the taxonomy so the event-creation
  // screen is server-driven like the rest.
  ...rows(TaxonomyKind.EVENT_TYPE, [
    ['birthday', 'Birthday'],
    ['anniversary', 'Anniversary'],
    ['generic', 'Custom Event'],
    ['special', 'Special Celebration'],
  ]),
];
