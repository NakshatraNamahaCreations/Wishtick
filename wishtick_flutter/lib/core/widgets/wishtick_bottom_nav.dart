import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// A destination in the app's primary navigation.
class WishtickNavItem {
  const WishtickNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The five-tab bottom bar from the Figma home frame (`51:11`): four labelled
/// destinations with a raised circular create button floating over the centre.
///
/// The create button is not a tab — it opens the create flow — so [onCreate] is
/// separate from [onDestinationSelected] and the centre slot is left empty in
/// [items].
class WishtickBottomNav extends StatelessWidget {
  const WishtickBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onCreate,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreate;

  static const items = <WishtickNavItem>[
    WishtickNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    WishtickNavItem(
      icon: Icons.card_giftcard_outlined,
      activeIcon: Icons.card_giftcard,
      label: 'Wishlist',
    ),
    WishtickNavItem(
      icon: Icons.photo_library_outlined,
      activeIcon: Icons.photo_library,
      label: 'Memories',
    ),
    WishtickNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.navBackground,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: [
              _tab(context, 0),
              _tab(context, 1),
              Expanded(child: Center(child: _createButton(context))),
              _tab(context, 2),
              _tab(context, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final colors = context.colors;
    final item = items[index];
    final selected = index == currentIndex;
    final color = selected ? colors.navSelected : colors.navUnselected;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: AppSizes.iconLg,
                color: color,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.label,
                style: context.text.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createButton(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Create',
      child: Material(
        color: colors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onCreate,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSizes.fabSize,
            height: AppSizes.fabSize,
            child: Icon(Icons.add, color: colors.onPrimary, size: 28),
          ),
        ),
      ),
    );
  }
}
