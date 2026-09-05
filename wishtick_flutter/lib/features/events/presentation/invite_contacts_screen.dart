import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/phone.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_providers.dart';

/// One person out of the host's address book, reduced to what an invite needs.
@immutable
class ContactCandidate {
  const ContactCandidate({required this.name, required this.phone});

  final String name;

  /// E.164. A contact whose number could not be read as one never becomes a
  /// candidate — see [candidatesFrom].
  final String phone;

  @override
  bool operator ==(Object other) =>
      other is ContactCandidate && other.phone == phone && other.name == name;

  @override
  int get hashCode => Object.hash(name, phone);
}

/// The address book, reduced to people who can actually be invited.
///
/// One entry per *number*, not per contact: a person saved with a mobile and a
/// landline is two rows, because the host has to choose which one to send to.
/// Anything that will not normalise is dropped rather than shown — an address
/// book is full of extensions and note fields, and inviting one makes a row
/// nobody can ever claim.
List<ContactCandidate> candidatesFrom(
  List<Contact> contacts, {
  required String defaultDialCode,
}) {
  final seen = <String>{};
  final out = <ContactCandidate>[];
  for (final contact in contacts) {
    final name = contact.displayName?.trim() ?? '';
    for (final number in contact.phones) {
      final e164 = normalizeToE164(
        number.number,
        defaultDialCode: defaultDialCode,
      );
      if (e164 == null || !seen.add(e164)) continue;
      out.add(
        ContactCandidate(
          name: name.isEmpty ? formatE164ForDisplay(e164) : name,
          phone: e164,
        ),
      );
    }
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// What reading the address book produced.
sealed class ContactsOutcome {
  const ContactsOutcome();
}

class ContactsReady extends ContactsOutcome {
  const ContactsReady(this.people);
  final List<ContactCandidate> people;
}

/// Refused. [permanently] means the OS will not ask again, so the only way
/// forward is Settings — and saying so is the difference between a dead
/// button and an explained one.
class ContactsRefused extends ContactsOutcome {
  const ContactsRefused({required this.permanently});
  final bool permanently;
}

class ContactsFailed extends ContactsOutcome {
  const ContactsFailed(this.message);
  final String message;
}

/// Reads the address book, asking the OS for permission first.
///
/// Behind a provider so a widget test can hand back a fixed list instead of
/// needing a real device with real contacts on it.
typedef ContactsReader =
    Future<ContactsOutcome> Function(String defaultDialCode);

final contactsReaderProvider = Provider<ContactsReader>(
  (ref) => _readDeviceContacts,
);

/// Opens this app's page in the OS settings.
///
/// Behind a provider for the same reason as [contactsReaderProvider], and one
/// more: the only thing that distinguishes the permanent-refusal button from
/// the ordinary one is *where it goes*, and a test that checks the label alone
/// passes just as happily when the button re-asks a permission the OS will
/// never grant.
typedef SettingsOpener = Future<void> Function();

final settingsOpenerProvider = Provider<SettingsOpener>(
  (ref) => FlutterContacts.permissions.openSettings,
);

Future<ContactsOutcome> _readDeviceContacts(String defaultDialCode) async {
  // `read`, not `readWrite`: nothing here writes a contact back, and asking
  // for write access would be asking for more than the feature needs. The
  // Android manifest declares the matching READ_CONTACTS and nothing more.
  //
  // flutter_contacts' own permission API rather than a general-purpose
  // permission package: it is the plugin that owns this permission, it draws
  // the "can I ask again?" distinction the refusal screen turns on, and it
  // knows about iOS 18's *limited* grant, where the reader picks which
  // contacts to share. A limited grant is a grant — the picker simply shows
  // the subset the reader chose.
  final status = await FlutterContacts.permissions.request(PermissionType.read);
  final granted =
      status == PermissionStatus.granted || status == PermissionStatus.limited;
  if (!granted) {
    return ContactsRefused(
      permanently:
          status == PermissionStatus.permanentlyDenied ||
          status == PermissionStatus.restricted,
    );
  }
  try {
    // Names and numbers only. Photos would be a second read of every row in
    // an address book that routinely runs to hundreds.
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    return ContactsReady(
      candidatesFrom(contacts, defaultDialCode: defaultDialCode),
    );
  } on Exception catch (e) {
    return ContactsFailed('$e');
  }
}

/// Why the app wants the address book, before the OS asks.
///
/// The system prompt is one line the app does not control, and a permission
/// sheet that appears with no explanation is the one people refuse. This says
/// what is read, what is sent, and what is not — and only "Continue" leads to
/// the OS prompt.
Future<bool> confirmContactsPermission(BuildContext context) async {
  final colors = context.colors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Invite people from your contacts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wishtick needs to read your contacts so you can pick who to '
            'invite by name instead of typing numbers.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Point(
            icon: Icons.phone_iphone,
            text:
                'Your contacts stay on your phone. Only the numbers you '
                'tick are sent, and only to invite them to this event.',
          ),
          _Point(
            icon: Icons.lock_outline,
            text:
                'This event stays private. Only the people you invite can '
                'open the link — anyone else is turned away.',
          ),
          _Point(
            icon: Icons.download_outlined,
            text:
                'Someone without Wishtick is sent to the app store first, '
                'and joins once they sign in with that number.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick contacts, send invitations.
///
/// Reached only after [confirmContactsPermission] was answered OK, so the OS
/// prompt this screen triggers on open is never the first thing a host sees.
class InviteContactsScreen extends ConsumerStatefulWidget {
  const InviteContactsScreen({required this.event, super.key});

  final WishtickEventDetail event;

  @override
  ConsumerState<InviteContactsScreen> createState() =>
      _InviteContactsScreenState();
}

class _InviteContactsScreenState extends ConsumerState<InviteContactsScreen> {
  ContactsOutcome? _outcome;
  final _picked = <String>{};
  String _query = '';
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _outcome = null);
    // The host's own number decides what a contact written without a country
    // code means: an address book is overwhelmingly people in the same place.
    final mine = ref.read(sessionProvider).user?.phone;
    final outcome = await ref.read(contactsReaderProvider)(
      dialCodeOf(mine) ?? kDefaultDialCode,
    );
    if (mounted) setState(() => _outcome = outcome);
  }

  Future<void> _send() async {
    if (_picked.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(eventsRepositoryProvider)
          .inviteByPhone(widget.event.id, _picked.toList());
      ref.invalidate(eventDetailProvider(widget.event.id));
      if (!mounted) return;
      Navigator.of(context).pop(result.created.length);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e.code) {
          'INVITE_LIMIT_REACHED' => 'This event has reached its guest limit.',
          'EVENT_NOT_PUBLISHED' =>
            'Publish the event before inviting anyone to it.',
          _ => e.message,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outcome = _outcome;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Invite from contacts'),
      body: SafeArea(
        child: switch (outcome) {
          null => const Center(child: CircularProgressIndicator()),
          ContactsRefused(:final permanently) => _Refused(
            permanently: permanently,
            onRetry: () => unawaited(_load()),
            onOpenSettings: () => unawaited(ref.read(settingsOpenerProvider)()),
          ),
          ContactsFailed(:final message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: WishtickErrorText(
                'Could not read your contacts.\n$message',
              ),
            ),
          ),
          ContactsReady(:final people) => _Picker(
            people: people,
            picked: _picked,
            query: _query,
            error: _error,
            sending: _sending,
            onQuery: (q) => setState(() => _query = q),
            onToggle: (phone) => setState(
              () => _picked.contains(phone)
                  ? _picked.remove(phone)
                  : _picked.add(phone),
            ),
            onSend: () => unawaited(_send()),
          ),
        },
      ),
    );
  }
}

/// Refused at the OS prompt. A permanent refusal cannot be re-asked from here,
/// so the only honest button is the one that opens Settings.
class _Refused extends StatelessWidget {
  const _Refused({
    required this.permanently,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanently;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: AppSizes.avatarLg,
              color: colors.primaryMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Wishtick cannot see your contacts',
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              permanently
                  ? 'Contacts permission is off for Wishtick, and your phone '
                        'will not ask again. Turn it on in Settings to pick '
                        'guests by name. You can still invite WishMates '
                        'without it.'
                  : 'Without it, guests have to be invited as WishMates '
                        'instead. You can try again whenever you like.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: permanently ? onOpenSettings : onRetry,
                child: Text(permanently ? 'Open Settings' : 'Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.people,
    required this.picked,
    required this.query,
    required this.error,
    required this.sending,
    required this.onQuery,
    required this.onToggle,
    required this.onSend,
  });

  final List<ContactCandidate> people;
  final Set<String> picked;
  final String query;
  final String? error;
  final bool sending;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onToggle;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final needle = query.trim().toLowerCase();
    final visible = needle.isEmpty
        ? people
        : people
              .where(
                (p) =>
                    p.name.toLowerCase().contains(needle) ||
                    p.phone.contains(needle),
              )
              .toList();

    if (people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'No contacts with a phone number on this device.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Said again here, not only in the dialog: this is the screen
              // where the host is actually choosing who gets in.
              Text(
                'Only the people you tick can open this event. Anyone else '
                'with the link is turned away.',
                style: context.text.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                onChanged: onQuery,
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final person = visible[i];
              return CheckboxListTile(
                value: picked.contains(person.phone),
                onChanged: sending ? null : (_) => onToggle(person.phone),
                title: Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  formatE164ForDisplay(person.phone),
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: WishtickErrorText(error!),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: picked.isEmpty || sending ? null : onSend,
                child: sending
                    ? SizedBox(
                        width: AppSizes.iconMd,
                        height: AppSizes.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Text(
                        picked.isEmpty
                            ? 'Select people to invite'
                            : 'Invite ${picked.length}',
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
