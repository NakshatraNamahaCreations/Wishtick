import type { Migration } from './migration.types';
import { migration001 } from './scripts/001-core-indexes';
import { migration002 } from './scripts/002-taxonomy-seed';
import { migration003 } from './scripts/003-wishlist-indexes';
import { migration004 } from './scripts/004-product-indexes';
import { migration005 } from './scripts/005-event-indexes';
import { migration006 } from './scripts/006-gift-indexes';
import { migration007 } from './scripts/007-group-gift-indexes';
import { migration008 } from './scripts/008-chat-indexes';
import { migration009 } from './scripts/009-notification-indexes';
import { migration010 } from './scripts/010-reel-indexes';
import { migration011 } from './scripts/011-admin-indexes';
import { migration012 } from './scripts/012-notification-ttl';
import { migration013 } from './scripts/013-taxonomy-v2';
import { migration014 } from './scripts/014-occasions-home-grid';
import { migration015 } from './scripts/015-address-indexes';
import { migration016 } from './scripts/016-order-indexes';
import { migration017 } from './scripts/017-conversion-indexes';
import { migration018 } from './scripts/018-settlement-indexes';
import { migration019 } from './scripts/019-relations';

/** Every migration must be registered here to run. Order comes from the id. */
export const MIGRATIONS: Migration[] = [
  migration001,
  migration002,
  migration003,
  migration004,
  migration005,
  migration006,
  migration007,
  migration008,
  migration009,
  migration010,
  migration011,
  migration012,
  migration013,
  migration014,
  migration015,
  migration016,
  migration017,
  migration018,
  migration019,
];

export { MigrationRunner } from './migration.runner';
export type { Migration } from './migration.types';
