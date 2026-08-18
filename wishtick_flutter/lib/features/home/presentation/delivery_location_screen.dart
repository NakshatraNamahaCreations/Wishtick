import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../addresses/data/addresses_repository.dart';
import '../../addresses/domain/address.dart';
import '../../addresses/presentation/add_address_screen.dart';
import '../../addresses/presentation/address_providers.dart';
import 'home_controller.dart';

/// Figma `2293:25` — "Select Delivery Location".
///
/// The pincode field checks the *format* only. There is no serviceability
/// lookup behind it, so it never claims an area is or is not covered — that
/// needs a courier integration Wishtick does not have.
class DeliveryLocationScreen extends ConsumerStatefulWidget {
  const DeliveryLocationScreen({super.key});

  @override
  ConsumerState<DeliveryLocationScreen> createState() =>
      _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState
    extends ConsumerState<DeliveryLocationScreen> {
  final _pincode = TextEditingController();
  String? _pincodeNote;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(homeProvider.notifier).ensureLoaded());
  }

  @override
  void dispose() {
    _pincode.dispose();
    super.dispose();
  }

  void _checkPincode() {
    final value = _pincode.text.trim();
    final valid = RegExp(r'^[1-9][0-9]{5}$').hasMatch(value);
    setState(() {
      _pincodeNote = valid
          ? 'That looks like a valid PIN code. Add an address to deliver here.'
          : 'Enter a six-digit Indian PIN code.';
    });
  }

  Future<void> _setDefault(Address address) async {
    if (address.isDefault) return;
    setState(() => _busy = true);
    try {
      await ref.read(addressesRepositoryProvider).setDefault(address.id);
      ref.invalidate(addressBookProvider);
      await ref.read(homeProvider.notifier).refresh();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Address address) async {
    setState(() => _busy = true);
    try {
      await ref.read(addressesRepositoryProvider).remove(address.id);
      ref.invalidate(addressBookProvider);
      await ref.read(homeProvider.notifier).refresh();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAddress() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddAddressScreen()),
    );
    if (added == true && mounted) {
      await ref.read(homeProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final addresses = ref.watch(homeProvider).addresses;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Delivery Location')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  TextField(
                    controller: _pincode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _checkPincode(),
                    decoration: InputDecoration(
                      hintText: 'Pincode',
                      counterText: '',
                      suffixIcon: TextButton(
                        onPressed: _checkPincode,
                        child: const Text('Check Pincode'),
                      ),
                    ),
                  ),
                  if (_pincodeNote != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _pincodeNote!,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _ActionRow(
                    icon: Icons.add_circle_outline,
                    label: 'Add New Address',
                    onTap: () => unawaited(_addAddress()),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Saved Address',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (addresses == null)
                    const Center(child: CircularProgressIndicator())
                  else if (addresses.isEmpty)
                    Text(
                      'No saved addresses yet.',
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    )
                  else
                    for (final address in addresses)
                      _AddressRow(
                        address: address,
                        enabled: !_busy,
                        onSelect: () => unawaited(_setDefault(address)),
                        onRemove: () => unawaited(_remove(address)),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: colors.accent, size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: context.text.titleSmall?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.enabled,
    required this.onSelect,
    required this.onRemove,
  });

  final Address address;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: enabled ? onSelect : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(
                address.isDefault
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: address.isDefault ? colors.primary : colors.border,
                size: AppSizes.iconMd,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label.display,
                    style: context.text.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    address.formatted,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.more_vert),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}
