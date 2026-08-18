import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../data/addresses_repository.dart';
import '../domain/address.dart';
import 'add_address_screen.dart';
import 'address_providers.dart';

/// "Address Book" (`324:1295`).
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref, {
    Address? edit,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddAddressScreen(existing: edit)),
    );
    if (saved == true) ref.invalidate(addressBookProvider);
  }

  /// "COPY" — the whole card as one block, ready to paste into a courier form
  /// or a message. The clipboard is the only sane reading of a copy action on
  /// an address card.
  Future<void> _copy(BuildContext context, Address address) async {
    await Clipboard.setData(
      ClipboardData(
        text: '${address.fullName}\n${address.formatted}\n${address.mobile}',
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address copied')));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text(address.formatted),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(addressesRepositoryProvider).remove(address.id);
    // Deleting the default promotes a survivor server-side, so the whole list
    // is refetched rather than the one row dropped locally.
    ref.invalidate(addressBookProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final book = ref.watch(addressBookProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Address Book'),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(
          text: 'Could not load your addresses.',
          onRetry: () => ref.invalidate(addressBookProvider),
        ),
        data: (addresses) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'SAVED ADDRESS',
              style: context.text.titleSmall?.copyWith(
                color: context.headlineBrandColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Text(
                  'No saved addresses yet.',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            for (final address in addresses) ...[
              _AddressCard(
                address: address,
                onEdit: () => unawaited(_open(context, ref, edit: address)),
                onCopy: () => unawaited(_copy(context, address)),
                onDelete: () => unawaited(_delete(context, ref, address)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            OutlinedButton(
              onPressed: () => unawaited(_open(context, ref)),
              child: const Text('ADD NEW ADDRESS'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved address, with the frame's EDIT / COPY / DELETE row beneath it.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  IconData get _icon => switch (address.label) {
    AddressLabel.home => Icons.home_outlined,
    AddressLabel.work => Icons.work_outline,
    AddressLabel.other => Icons.place_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: AppSizes.iconLg, color: colors.textPrimary),
              const SizedBox(width: AppSpacing.md),
              Text(
                address.label.display,
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (address.isDefault) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '· Default',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            address.fullName,
            style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            address.formatted,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Phone Number: ${address.mobile}',
            style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _CardAction(label: 'EDIT', onTap: onEdit),
              const SizedBox(width: AppSpacing.xxl),
              _CardAction(label: 'COPY', onTap: onCopy),
              const SizedBox(width: AppSpacing.xxl),
              _CardAction(label: 'DELETE', onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.xs),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.xxs,
      ),
      child: Text(
        label,
        style: context.text.labelLarge?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
