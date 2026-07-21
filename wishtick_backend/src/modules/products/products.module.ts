import { BullModule } from '@nestjs/bullmq';
import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { SsrfGuard } from 'src/common/net/ssrf-guard';
import type { AppConfig } from 'src/config/configuration';
import { QUEUE } from 'src/infra/queue/queue.constants';
import { TaxonomyModule } from 'src/modules/taxonomy/taxonomy.module';
import { WishlistsModule } from 'src/modules/wishlists/wishlists.module';
import { AffiliateSyncProcessor } from './affiliate-sync.processor';
import { AffiliateSyncService } from './affiliate-sync.service';
import { ClickTrackingService } from './click-tracking.service';
import { ProductImportController } from './product-import.controller';
import { ProductImportService } from './product-import.service';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { FixtureProductProvider } from './providers/fixture-provider';
import { PRODUCT_PROVIDER, type IProductProvider } from './providers/product-provider.port';
import { ProviderGuard } from './providers/provider-guard.service';
import { RedirectController } from './redirect.controller';
import { ClickEvent, ClickEventSchema } from './schemas/click-event.schema';
import { Product, ProductSchema } from './schemas/product.schema';
import { UrlResolverService } from './url-resolver.service';

const logger = new Logger('ProductsModule');

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Product.name, schema: ProductSchema },
      { name: ClickEvent.name, schema: ClickEventSchema },
    ]),
    BullModule.registerQueue({ name: QUEUE.AFFILIATE_SYNC }),
    // For AccessPolicyService, WishlistsService, and the WishlistItem model.
    // The dependency runs one way only: products know about wishlists, never
    // the reverse — a wishlist must not know what an affiliate network is.
    WishlistsModule,
    TaxonomyModule,
  ],
  controllers: [ProductsController, ProductImportController, RedirectController],
  providers: [
    ProductsService,
    ProductImportService,
    AffiliateSyncService,
    AffiliateSyncProcessor,
    ClickTrackingService,
    UrlResolverService,
    ProviderGuard,
    SsrfGuard,
    FixtureProductProvider,
    {
      provide: PRODUCT_PROVIDER,
      inject: [ConfigService, FixtureProductProvider],
      useFactory: (
        config: ConfigService<AppConfig, true>,
        fixture: FixtureProductProvider,
      ): IProductProvider => {
        const driver = config.get('products.provider', { infer: true });

        // The fixture catalogue is invented data. Serving it in production would
        // show users products that do not exist and links that go nowhere.
        // Fail the boot instead — this is exactly the sort of placeholder that
        // otherwise reaches production because nobody remembered to swap it.
        if (driver === 'fixture' && config.get('app.isProduction', { infer: true })) {
          throw new Error(
            'PRODUCT_PROVIDER=fixture is not usable in production — configure a real affiliate provider',
          );
        }

        logger.log(`Product provider: ${driver}`);
        return fixture;
      },
    },
  ],
  exports: [ProductsService, ProductImportService, AffiliateSyncService, PRODUCT_PROVIDER],
})
export class ProductsModule {}
