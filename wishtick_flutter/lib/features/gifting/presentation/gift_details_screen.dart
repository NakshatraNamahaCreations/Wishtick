import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/sparkle_icon.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../addresses/domain/address.dart';
import '../../addresses/presentation/add_address_screen.dart';
import '../../addresses/presentation/address_providers.dart';
import '../../home/presentation/home_controller.dart';
import '../../wishlist/presentation/widgets/product_detail_body.dart';
import '../data/gifting_repository.dart';
import 'gift_item_controller.dart';

/// The message length the mock's counter implies (`12/40`).
const _messageMaxLength = 40;

/// Figma `316:834` — the last step before the merchant hand-off.
///
/// The mock's CTA reads "Proceed to Pay". Wishtick takes no payment: the buy
/// happens at the merchant, through the affiliate redirect, so the button says
/// what it does. The delivery address is here because the merchant's own
/// checkout will ask for it and the mock puts a COPY action on the card —
/// this is the address you paste over there, not one Wishtick ships to.
class GiftDetailsScreen extends ConsumerStatefulWidget {
  const GiftDetailsScreen({
    required this.wishlistId,
    required this.itemId,
    super.key,
  });

  final String wishlistId;
  final String itemId;

  @override
  ConsumerState<GiftDetailsScreen> createState() => _GiftDetailsScreenState();
}

class _GiftDetailsScreenState extends ConsumerState<GiftDetailsScreen> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  (String, String) get _arg => (widget.wishlistId, widget.itemId);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(giftItemProvider(_arg).notifier).ensureLoaded();
      ref.read(homeProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddAddressScreen()),
    );
    if (added == true && mounted) {
      ref.invalidate(addressBookProvider);
      await ref.read(homeProvider.notifier).refresh();
    }
  }

  Future<void> _copy(Address address) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${address.fullName}\n${address.formatted}\n'
            'Phone: ${address.mobile}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied — paste it at checkout.')),
    );
  }

  /// Opens the merchant through Wishtick's redirect, then asks whether it went
  /// through. Nothing on the affiliate path tells us a sale happened in time
  /// for this screen, so the gifter is the only source — which is exactly what
  /// `POST /gifts/:id/purchase` is for.
  Future<void> _continueToStore() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final uri = ref
        .read(giftingRepositoryProvider)
        .affiliateRedirectUri(widget.itemId);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!opened) {
      setState(() => _error = 'Could not open the store.');
      return;
    }

    final bought = await _askIfPurchased();
    if (bought != true || !mounted) return;

    setState(() => _busy = true);
    final note = _message.text.trim();
    final gift = await ref
        .read(giftItemProvider(_arg).notifier)
        .markPurchased(note: note.isEmpty ? null : note);
    if (!mounted) return;
    setState(() => _busy = false);

    if (gift == null) {
      setState(() => _error = ref.read(giftItemProvider(_arg)).error);
      return;
    }
    context.pushReplacement(AppRoutes.orderConfirmed(gift.id));
  }

  Future<bool?> _askIfPurchased() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Did you complete the purchase?'),
      content: const Text(
        'Saying yes creates the order and tells the wishlist this gift is '
        'taken care of.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not yet'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes, I bought it'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(giftItemProvider(_arg));
    final addresses = ref.watch(homeProvider).addresses;
    final colors = context.colors;
    final item = state.item;

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SafeArea(
        child: item == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        ProductDetailHeader(
                          title: item.title,
                          subtitle: item.category,
                          imageUrl: item.coverImageUrl,
                          amountMinor: item.price.amountMinor,
                          notes: null,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Enter Few Details To Help Us Deliver You Gift',
                          style: context.text.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Deliver To',
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _AddAddressLink(onTap: () => unawaited(_addAddress())),
                        const SizedBox(height: AppSpacing.md),
                        if (addresses == null)
                          const Center(child: CircularProgressIndicator())
                        else if (addresses.isEmpty)
                          Text(
                            'No saved addresses yet. Add one so you can paste '
                            'it at the merchant’s checkout.',
                            style: context.text.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          )
                        else
                          for (final address in addresses)
                            _AddressCard(
                              address: address,
                              onCopy: () => unawaited(_copy(address)),
                            ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Gift Message (Optional)',
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _message,
                          maxLines: 3,
                          maxLength: _messageMaxLength,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Happy Birthday!',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _QuickSuggestions(
                          recipientName: item.recipientName,
                          onPick: (text) => setState(() {
                            _message.text = text;
                          }),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          WishtickErrorText(_error!),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy
                            ? null
                            : () => unawaited(_continueToStore()),
                        child: Text(_busy ? 'Opening…' : 'Continue to Store'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AddAddressLink extends StatelessWidget {
  const _AddAddressLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: colors.primary,
              size: AppSizes.iconMd,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add Delivery Address',
              style: context.text.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onCopy});

  final Address address;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: address.isDefault ? colors.primary : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.home_outlined,
                size: AppSizes.iconMd,
                color: colors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                address.label.display,
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.fullName),
                Text(address.formatted),
                Text('Phone Number: ${address.mobile}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The mock offers EDIT / COPY / DELETE. Only COPY is here: editing
          // and deleting an address belong to the address book, and doing them
          // mid-purchase would change an address you may be about to paste.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onCopy, child: const Text('COPY')),
          ),
        ],
      ),
    );
  }
}

/// The mock's message chips, with the recipient's name filled in when the item
/// carries one.
class _QuickSuggestions extends StatelessWidget {
  const _QuickSuggestions({required this.recipientName, required this.onPick});

  final String? recipientName;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = recipientName;
    final suggestions = [
      name == null ? 'Happy birthday!' : 'Happy birthday $name!',
      'Hope You Like the Gift!',
      'Have a Beautiful Birthday!!',
    ].where((s) => s.length <= _messageMaxLength).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Quick Suggestions',
              style: context.text.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SparkleIcon(size: AppSizes.iconSm, color: colors.accent),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                label: Text(suggestion),
                backgroundColor: colors.primarySubtle,
                side: BorderSide.none,
                labelStyle: context.text.bodySmall?.copyWith(
                  color: colors.primary,
                ),
                onPressed: () => onPick(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}
