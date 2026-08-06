import { SerpApiProductProvider } from './serpapi-provider';
import type { SerpApiClient } from './serpapi.client';
import type { SerpImmersiveProductResponse, SerpShoppingResponse } from './serpapi.types';

/**
 * The normalization layer, tested on its own.
 *
 * Everything here is a shape SerpApi has actually been observed to return —
 * missing fields, a price that is only a string, an `old_price` equal to the
 * current one, sellers with no direct link. The adapter must degrade on every
 * one of them rather than throw, because a single odd row would otherwise take
 * out a whole search page.
 */
describe('SerpApiProductProvider', () => {
  const build = (shopping?: SerpShoppingResponse, product?: SerpImmersiveProductResponse) => {
    const shoppingFn = jest.fn().mockResolvedValue(shopping ?? {});
    const productFn = jest.fn().mockResolvedValue(product ?? {});
    const client = {
      shopping: shoppingFn,
      immersiveProduct: productFn,
    } as unknown as SerpApiClient;
    return { provider: new SerpApiProductProvider(client), shoppingFn, productFn };
  };

  const query = { page: 1, pageSize: 20 };

  describe('search', () => {
    it('normalizes a shopping row into minor units', async () => {
      const { provider } = build({
        shopping_results: [
          {
            product_id: 'p1',
            title: 'Sony WH-1000XM5',
            source: 'Amazon.in',
            extracted_price: 29990,
            thumbnail: 'https://img.example/1.jpg',
            product_link: 'https://www.google.com/shopping/product/p1',
            rating: 4.5,
            reviews: 1200,
          },
        ],
      });

      const result = await provider.search({ ...query, q: 'headphones' });
      const item = result.items[0];

      // 29,990 rupees → 2,999,000 paise. A float here would drift the moment
      // anything sums it.
      expect(item.amountMinor).toBe(2_999_000);
      expect(item.externalId).toBe('p1');
      expect(item.merchant).toBe('Amazon.in');
      expect(item.currency).toBe('INR');
      // Search never invents a monetized link — that is the network's job.
      expect(item.affiliateUrl).toBeNull();
    });

    it('captures the immersive token, without which nothing can be monetized', async () => {
      const { provider } = build({
        shopping_results: [
          {
            product_id: 'p1',
            title: 'X',
            product_link: 'https://google/p1',
            immersive_product_page_token: 'tok-abc',
          },
        ],
      });

      const item = (await provider.search({ ...query, q: 'x' })).items[0];
      // The retired `google_product` engine took a product id; its replacement
      // takes this token, and a search is the only place it exists. Losing it
      // here means the product can never reach a merchant URL.
      expect(item.affiliateMeta.serpapi).toMatchObject({
        immersiveToken: 'tok-abc',
        merchantLinkResolved: false,
      });
      // productUrl is Google's own page at this stage — real, but unmonetizable.
      expect(item.productUrl).toBe('https://google/p1');
    });

    it('treats SerpApi’s "no results" as empty, not as an outage', async () => {
      // SerpApi answers 200 with an `error` string when Google matched nothing.
      // Throwing would trip the circuit breaker on a query that simply has no
      // results, taking search down for everyone else.
      const { provider } = build({ error: "Google hasn't returned any results" });

      const result = await provider.search({ ...query, q: 'asdfghjkl' });
      expect(result.items).toEqual([]);
      expect(result.totalEstimate).toBe(0);
    });

    it('drops rows with no id or no title rather than failing the page', async () => {
      const { provider } = build({
        shopping_results: [
          { title: 'No id' },
          { product_id: 'p2' },
          { product_id: 'p3', title: 'Good' },
        ],
      });

      const result = await provider.search({ ...query, q: 'x' });
      expect(result.items).toHaveLength(1);
      expect(result.items[0].externalId).toBe('p3');
    });

    it('shows a list price only when it is genuinely higher', async () => {
      const { provider } = build({
        shopping_results: [
          { product_id: 'a', title: 'Discounted', extracted_price: 100, extracted_old_price: 150 },
          { product_id: 'b', title: 'Not really', extracted_price: 100, extracted_old_price: 100 },
        ],
      });

      const [discounted, flat] = (await provider.search({ ...query, q: 'x' })).items;
      expect(discounted.listPriceMinor).toBe(15_000);
      // Google echoes the current price into old_price often enough that
      // rendering it would invent a saving of ₹0.
      expect(flat.listPriceMinor).toBeNull();
    });

    it('carries the searched shelf, never a guess about the product', async () => {
      const { provider } = build({
        shopping_results: [{ product_id: 'p1', title: 'X' }],
      });

      const shelved = await provider.search({ ...query, category: 'electronics' });
      expect(shelved.items[0].category).toBe('electronics');

      const keyword = await provider.search({ ...query, q: 'blue mug' });
      expect(keyword.items[0].category).toBeNull();
    });

    it('pages over the single response instead of buying another', async () => {
      const rows = Array.from({ length: 25 }, (_, i) => ({
        product_id: `p${i}`,
        title: `Item ${i}`,
      }));
      const { provider, shoppingFn } = build({ shopping_results: rows });

      const second = await provider.search({ q: 'x', page: 2, pageSize: 10 });

      expect(second.items).toHaveLength(10);
      expect(second.items[0].externalId).toBe('p10');
      expect(second.hasMore).toBe(true);
      // Google Shopping ignores `start`, so a second page must not cost a
      // second search.
      expect(shoppingFn).toHaveBeenCalledTimes(1);
    });

    it('asks for nothing when there is neither a keyword, a shelf, nor a price', async () => {
      const { provider, shoppingFn } = build();

      const result = await provider.search({ ...query, category: 'not-a-shelf' });

      expect(result.items).toEqual([]);
      expect(shoppingFn).not.toHaveBeenCalled();
    });

    it('treats a price-only search as a browse rather than returning nothing', async () => {
      const { provider, shoppingFn } = build({
        shopping_results: [{ product_id: 'p1', title: 'Under budget' }],
      });

      // Discover's price-band and premium shelves search with *only* a price.
      // The fixture catalogue filtered its in-memory list; a keyword engine
      // cannot, and returning empty silently killed both shelves on the live
      // feed — 200 in 24ms with no products.
      const result = await provider.search({ ...query, maxPriceMinor: 200_000 });

      expect(result.items).toHaveLength(1);
      expect(shoppingFn).toHaveBeenCalledWith(
        expect.objectContaining({ q: 'gifts', maxPriceMinor: 200_000 }),
      );
    });

    it('converts minor-unit price filters to the major units SerpApi wants', async () => {
      const { provider, shoppingFn } = build({ shopping_results: [] });

      await provider.search({ ...query, q: 'x', minPriceMinor: 150_000, maxPriceMinor: 999_900 });

      expect(shoppingFn).toHaveBeenCalledWith(
        expect.objectContaining({ minPriceMinor: 150_000, maxPriceMinor: 999_900 }),
      );
    });
  });

  describe('getDetailsByRef', () => {
    const ref = (token = 'tok-1') => ({ serpapi: { immersiveToken: token } });

    it('prefers the cheapest total, not the cheapest sticker', async () => {
      const { provider } = build(undefined, {
        product_results: {
          title: 'Kettle',
          stores: [
            {
              name: 'CheapSticker',
              link: 'https://cheap.example/p',
              extracted_price: 1899,
              extracted_total: 2199,
            },
            {
              name: 'BetterTotal',
              link: 'https://better.example/p',
              extracted_price: 1999,
              extracted_total: 1999,
            },
          ],
        },
      });

      const product = await provider.getDetailsByRef('p1', ref());

      // Sorting on the sticker price would send the buyer to the ₹200-shipping
      // store and call it the better deal.
      expect(product!.merchant).toBe('BetterTotal');
      expect(product!.productUrl).toBe('https://better.example/p');
      expect(product!.amountMinor).toBe(199_900);
      expect(product!.affiliateMeta.serpapi).toMatchObject({ merchantLinkResolved: true });
    });

    it('ignores stores with no link', async () => {
      const { provider } = build(undefined, {
        product_results: {
          title: 'Kettle',
          stores: [
            { name: 'NoLink', extracted_total: 1 },
            { name: 'Real', link: 'https://real.example/p', extracted_total: 500 },
          ],
        },
      });

      // There is nowhere to send anyone, so a ₹1 listing without a link is
      // worse than useless.
      expect((await provider.getDetailsByRef('p1', ref()))!.merchant).toBe('Real');
    });

    it('reports no store as out of stock, with Google’s page as a fallback', async () => {
      const { provider } = build(undefined, {
        product_results: { title: 'Discontinued', stores: [] },
      });

      const product = await provider.getDetailsByRef('p9', ref());
      expect(product!.inStock).toBe(false);
      expect(product!.productUrl).toContain('google.com/shopping/product/p9');
      expect(product!.affiliateMeta.serpapi).toMatchObject({ merchantLinkResolved: false });
    });

    it('returns null for a delisted product rather than throwing', async () => {
      const { provider } = build(undefined, { error: 'No product found' });
      // Null is the port's "genuinely no such product"; a throw would mean
      // "the API is down" and would be flagged as an outage.
      expect(await provider.getDetailsByRef('gone', ref())).toBeNull();
    });

    it('spends no call when there is no stored token', async () => {
      const { provider, productFn } = build();

      // `engine=google_product` was retired, and its replacement is keyed by a
      // token only a search can produce. Without one there is nothing to ask.
      expect(await provider.getDetailsByRef('p1', {})).toBeNull();
      expect(productFn).not.toHaveBeenCalled();
    });

    it('getDetails alone cannot answer — an id is no longer enough', async () => {
      const { provider, productFn } = build();
      expect(await provider.getDetails()).toBeNull();
      expect(productFn).not.toHaveBeenCalled();
    });
  });

  it('declines to resolve merchant URLs, so the scraper takes over', async () => {
    const { provider } = build();
    // SerpApi has no reverse lookup. Claiming one would strand every pasted
    // Flipkart link on an adapter that cannot answer.
    expect(await provider.resolveUrl()).toBeNull();
  });
});
