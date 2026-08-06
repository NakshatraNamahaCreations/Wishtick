/// Derives a merchant name from a product link's host — the backend has no
/// merchant field on a persisted item, only whatever `productLink` was saved.
/// Returns null for a link (or lack of one) that doesn't match a known
/// retailer, rather than guessing.
String? merchantLabel(String? productLink) {
  if (productLink == null || productLink.isEmpty) return null;
  final host = Uri.tryParse(productLink)?.host.toLowerCase();
  if (host == null) return null;

  if (host.contains('amazon')) return 'Amazon';
  if (host.contains('flipkart')) return 'Flipkart';
  if (host.contains('myntra')) return 'Myntra';
  if (host.contains('nike')) return 'Nike';
  if (host.contains('apple')) return 'Apple Store';
  if (host.contains('sony')) return 'Sony';
  if (host.contains('fossil')) return 'Fossil';
  if (host.contains('bose')) return 'Bose';
  if (host.contains('fujifilm')) return 'Fujifilm';
  if (host.contains('lecreuset')) return 'Le Creuset';
  return null;
}
