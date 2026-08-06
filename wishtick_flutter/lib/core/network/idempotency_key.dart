import 'dart:math';

/// Mints the `Idempotency-Key` header the backend demands on the write routes
/// that must never double-fire — reserving an item, recording an offline gift,
/// creating a group gift, contributing to one.
///
/// The point is that the key is minted **once per user intent**, then reused
/// across every retry of that intent. Minting a fresh key inside a retry loop
/// would defeat the whole mechanism: the server would see two distinct
/// requests and honour both.
///
/// Backend accepts 8–200 characters; this produces 32 hex characters.
String newIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
