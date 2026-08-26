import 'package:flutter/material.dart';

import '../../../../core/widgets/occasion_picker_grid.dart';
import '../create_memory_controller.dart';

/// The eight illustrated occasion cards on `4104:1539`.
///
/// The grid itself is [OccasionPickerGrid], shared with event creation: the
/// two frames draw the same picker, and while this screen owned a copy of it
/// the copy kept the stand-in glyphs after the event screen was given the real
/// `Celebrations_images` photographs.
class OccasionGrid extends StatelessWidget {
  const OccasionGrid({
    required this.selectedKey,
    required this.onSelect,
    super.key,
  });

  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return OccasionPickerGrid(
      occasions: kMemoryOccasions,
      selectedKey: selectedKey,
      onSelect: onSelect,
    );
  }
}
