import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/addresses_repository.dart';
import '../domain/address.dart';
import 'address_providers.dart';

/// "Add New Address" (`324:1340`), reused as "Edit Address" when [existing] is
/// given.
///
/// One screen for both because the frame set has no separate edit design and
/// the field list is identical — only the title, the prefilled values and the
/// call at the end differ.
class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({this.existing, super.key});

  final Address? existing;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _fullName = TextEditingController(
    text: widget.existing?.fullName ?? '',
  );
  late final _mobile = TextEditingController(
    text: widget.existing?.mobile ?? '',
  );
  late final _altMobile = TextEditingController(
    text: widget.existing?.altMobile ?? '',
  );
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _line1 = TextEditingController(text: widget.existing?.line1 ?? '');
  late final _locality = TextEditingController(
    text: widget.existing?.locality ?? '',
  );
  late final _landmark = TextEditingController(
    text: widget.existing?.landmark ?? '',
  );
  late final _pincode = TextEditingController(
    text: widget.existing?.pincode ?? '',
  );
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _state = TextEditingController(text: widget.existing?.state ?? '');

  late AddressLabel _label = widget.existing?.label ?? AddressLabel.home;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _mobile,
      _altMobile,
      _email,
      _line1,
      _locality,
      _landmark,
      _pincode,
      _city,
      _state,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Empty means "not given" for the optional fields, not an empty string —
  /// the server normalises the same way, and sending `""` would store one.
  String? _optional(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(addressesRepositoryProvider);
      final existing = widget.existing;
      if (existing == null) {
        await repo.create(
          label: _label,
          fullName: _fullName.text.trim(),
          mobile: _mobile.text.trim(),
          altMobile: _optional(_altMobile),
          email: _optional(_email),
          line1: _line1.text.trim(),
          locality: _locality.text.trim(),
          landmark: _optional(_landmark),
          pincode: _pincode.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
        );
      } else {
        await repo.update(
          existing.id,
          label: _label,
          fullName: _fullName.text.trim(),
          mobile: _mobile.text.trim(),
          altMobile: _optional(_altMobile),
          email: _optional(_email),
          line1: _line1.text.trim(),
          locality: _locality.text.trim(),
          landmark: _optional(_landmark),
          pincode: _pincode.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
        );
      }
      ref.invalidate(addressBookProvider);
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

  String? _required(String? value, String what) =>
      (value == null || value.trim().isEmpty) ? 'Please enter $what' : null;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: circleBackAppBar(
        context,
        title: isEdit ? 'Edit Address' : 'Add New Address',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const _SectionHeading('Contact Information'),
            const SizedBox(height: AppSpacing.lg),
            _AddressField(
              controller: _fullName,
              hint: 'Full Name',
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'a name'),
            ),
            _AddressField(
              controller: _mobile,
              hint: 'Mobile Number',
              keyboardType: TextInputType.phone,
              inputFormatters: _phoneOnly,
              validator: (v) => _required(v, 'a mobile number'),
            ),
            _AddressField(
              controller: _altMobile,
              hint: 'Alternate Mobile Number',
              keyboardType: TextInputType.phone,
              inputFormatters: _phoneOnly,
            ),
            _AddressField(
              controller: _email,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: AppSpacing.xxxl),
            const _SectionHeading('Address Information'),
            const SizedBox(height: AppSpacing.lg),
            _AddressField(
              controller: _line1,
              hint: 'Flat No / Building Name',
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'a flat or building'),
            ),
            _AddressField(
              controller: _locality,
              hint: 'Locality / Area',
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'a locality'),
            ),
            _AddressField(
              controller: _landmark,
              hint: 'Landmark',
              textCapitalization: TextCapitalization.words,
            ),
            _AddressField(
              controller: _pincode,
              hint: 'Pincode',
              keyboardType: TextInputType.number,
              validator: (v) => _required(v, 'a pincode'),
            ),
            _AddressField(
              controller: _city,
              hint: 'City',
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'a city'),
            ),
            _AddressField(
              controller: _state,
              hint: 'State',
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'a state'),
            ),

            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'Save address as',
              style: context.text.titleMedium?.copyWith(
                color: context.headlineBrandColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (final option in AddressLabel.values)
                  Expanded(
                    child: _LabelRadio(
                      option: option,
                      selected: _label,
                      onChanged: (v) => setState(() => _label = v),
                    ),
                  ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              WishtickErrorText(_error!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              child: Text(isEdit ? 'Save Changes' : 'Save Address'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Digits, spaces, dashes and a leading `+` — what the server's phone pattern
/// accepts. Blocking the rest at the keyboard beats a validation message.
final _phoneOnly = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +-]')),
];

/// "Contact Information *" / "Address Information *" — the red asterisk is
/// part of the heading in the frame, so it is drawn here rather than repeated
/// on every field.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = context.text.titleMedium?.copyWith(
      color: context.colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        text: text,
        style: style,
        children: [
          TextSpan(
            text: ' *',
            style: style?.copyWith(color: context.colors.danger),
          ),
        ],
      ),
    );
  }
}

/// A white pill field with placeholder-only labelling, as the frame draws it.
class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(hintText: hint),
    ),
  );
}

/// One of the three "Save address as" radios.
class _LabelRadio extends StatelessWidget {
  const _LabelRadio({
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  final AddressLabel option;
  final AddressLabel selected;
  final ValueChanged<AddressLabel> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelected = option == selected;

    return InkWell(
      onTap: () => onChanged(option),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: AppSizes.iconMd,
              color: isSelected ? colors.primary : colors.primaryMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              option.display,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
