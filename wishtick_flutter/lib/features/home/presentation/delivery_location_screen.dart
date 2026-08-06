import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/home_repository.dart';
import '../domain/address.dart';
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
      await ref
          .read(homeRepositoryProvider)
          .updateAddress(address.id, isDefault: true);
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
      await ref.read(homeRepositoryProvider).removeAddress(address.id);
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
                    address.label,
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

/// The "Add New Address" form behind the picker.
class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _label,
      _recipient,
      _phone,
      _line1,
      _line2,
      _city,
      _state,
      _pincode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(homeRepositoryProvider)
          .createAddress(
            label: _label.text.trim(),
            recipientName: _recipient.text.trim(),
            phone: _phone.text.trim(),
            line1: _line1.text.trim(),
            line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            pincode: _pincode.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? 'Please enter $label' : null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Address')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (_error != null) ...[
                      WishtickErrorText(_error!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _Field(
                      controller: _label,
                      label: 'Label',
                      hint: 'Home, Work…',
                      validator: (v) => _required(v, 'a label'),
                    ),
                    _Field(
                      controller: _recipient,
                      label: 'Recipient name',
                      hint: 'Who receives the parcel',
                      validator: (v) => _required(v, "the recipient's name"),
                    ),
                    _Field(
                      controller: _phone,
                      label: 'Phone',
                      hint: '+91…',
                      keyboardType: TextInputType.phone,
                      validator: (v) => _required(v, 'a phone number'),
                    ),
                    _Field(
                      controller: _line1,
                      label: 'Flat / house and building',
                      validator: (v) => _required(v, 'an address'),
                    ),
                    _Field(
                      controller: _line2,
                      label: 'Street, area, landmark (optional)',
                    ),
                    _Field(
                      controller: _city,
                      label: 'City',
                      validator: (v) => _required(v, 'a city'),
                    ),
                    _Field(
                      controller: _state,
                      label: 'State',
                      validator: (v) => _required(v, 'a state'),
                    ),
                    _Field(
                      controller: _pincode,
                      label: 'PIN code',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) =>
                          RegExp(r'^[1-9][0-9]{5}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Enter a six-digit Indian PIN code',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => unawaited(_save()),
                    child: _busy
                        ? SizedBox(
                            width: AppSizes.iconMd,
                            height: AppSizes.iconMd,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Text('Save Address'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
        ),
      ),
    );
  }
}
