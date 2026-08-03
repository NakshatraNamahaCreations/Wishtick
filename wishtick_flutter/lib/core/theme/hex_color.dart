import 'package:flutter/material.dart';

/// Builds a [Color] from a server-supplied `#RRGGBB` string.
///
/// This is the one sanctioned way to turn *runtime design data* (taxonomy
/// colour swatches, remote-config accents) into a [Color]. It holds no colour
/// of its own — [fallback] decides what an unparseable value renders as — so it
/// does not undermine the palette rule; the design-system guard allowlists this
/// file for the constructor call only.
Color parseHexColor(String hex, {required Color fallback}) {
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
