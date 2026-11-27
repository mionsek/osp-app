import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/providers.dart';
import '../../models/member_note.dart';
import '../../models/sync_state.dart' show RejectedChange;
import '../../core/utils/time_format.dart';
import '../../services/google_drive_service.dart';
import '../../services/sync_service.dart' show LastPersonalAdminException;
import '../../core/theme/osp_theme.dart';
import '../../widgets/shared_account_guide.dart';

/// Zarządzanie dostępem do jednostki: kto może z niej korzystać i kto ma
/// uprawnienia administratora.
///
/// Widoczne tylko dla administratora — zwykły użytkownik i tak nie mógłby
/// nic tu zmienić.
class UnitMembersSection extends ConsumerStatefulWidget {
  const UnitMembersSection({super.key});

  /// Systemowe okno „Udostępnij" z tekstem (SMS, WhatsApp, Messenger,
  /// poczta). Podmieniane w testach.
  @visibleForTesting
  static Future<void> Function(String text) shareText = (text) =>
      SharePlus.instance.share(ShareParams(
        text: text,
        subject: 'Zaproszenie do Raporty OSP',
      ));

  @override
  ConsumerState<UnitMembersSection> createState() =>
      _UnitMembersSectionState();
}

class _UnitMembersSectionState extends ConsumerState<UnitMembersSection> {
  List<UnitMemberAccess>? _members;
  Map<String, MemberNote> _notes = const {};
  bool _loading = false;
  String? _error;

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sync = ref.read(syncServiceProvider);
      final members = await sync.listMembers();
      // Notatki „kto dołączył" (feature/080) — ich brak nie może zablokować
      // samej listy uprawnień.
      var notes = const <String, MemberNote>{};
      try {
        notes = await sync.memberNotes();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _members = members;
          _notes = notes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się pobrać listy: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _InviteDialog(onServer: ref.read(syncServiceProvider).onServer),
    );
    if (email == null || email.isEmpty || !mounted) return;

    if (!email.contains('@')) {
      setState(() => _error = 'To nie wygląda na adres e-mail.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await ref.read(syncServiceProvider).inviteMember(email);
      await _loadMembers();
      if (mounted) await _offerToSend(email, message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się zaprosić: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Powiadomienie Google o udostępnieniu wygląda jak każde inne z Dysku
  /// i bywa w Spamie — zaproszony Dawid zobaczył folder, a e-maila
  /// z zaproszeniem nie rozpoznał (19.11.2026). Dlatego od razu propozycja
  /// wysłania tej samej treści SMS-em albo komunikatorem.
  Future<void> _offerToSend(String email, String message) async {
    final code = ref.read(syncStateProvider).unitInviteCode ?? '';
    final onServer = ref.read(syncServiceProvider).onServer;
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zaproszenie wysłane'),
        content: Text(
          onServer
              ? '$email jest na liście zaproszonych. Wyślij tej osobie kod '
                  '$code SMS-em, komunikatorem albo e-mailem — po '
                  'zalogowaniu tym adresem i wpisaniu kodu dołączy do '
                  'jednostki.'
              : 'Google wyśle na $email powiadomienie o udostępnieniu '
                  'folderu jednostki z kodem $code. Wygląda jak zwykłe '
                  'udostępnienie z Dysku i bywa w Spamie — przekaż kod także '
                  'SMS-em albo komunikatorem.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Gotowe'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Udostępnij kod'),
          ),
        ],
      ),
    );
    if (send == true) await UnitMembersSection.shareText(message);
  }

  Future<void> _toggleAdmin(UnitMemberAccess member, bool makeAdmin) async {
    final sync = ref.read(syncServiceProvider);
    try {
      if (makeAdmin) {
        await sync.grantAdmin(member.email);
      } else {
        await sync.revokeAdmin(member.email);
      }
      if (mounted) setState(() {});
    } on LastPersonalAdminException catch (e) {
      if (mounted) setState(() => _error = '$e');
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się zmienić: $e');
    }
  }

  /// Wspólne konto jednostki, np. tablet w samochodzie — patrz
  /// [SyncState.sharedFounder].
  Future<void> _toggleShared(bool shared) async {
    final syncState = ref.read(syncStateProvider);
    final founder = syncState.founderEmail ?? '';
    final onThisAccount = syncState.isFounder(syncState.userEmail ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(shared
            ? 'Konto jednostki jako wspólne?'
            : 'Wyłączyć wspólne konto?'),
        content: Text(shared
            ? '$founder będzie działać jak konto zwykłego członka: doda '
                'wyjazdy i przekazania mienia i poprawi tylko te dodane '
                'z niego, ale nie zmieni ustawień jednostki, list ani '
                'uprawnień. Przy każdym wpisie zapyta, kto wpisuje.\n\n'
                'Cofnąć to może tylko administrator na własnym koncie.'
                '${onThisAccount ? '\n\nTo konto, na którym jesteś — '
                    'od razu stracisz tu uprawnienia administratora.' : ''}'
            : '$founder odzyska uprawnienia administratora na każdym '
                'urządzeniu, na którym jest zalogowane, i przestanie pytać, '
                'kto wpisuje.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(shared ? 'Włącz' : 'Wyłącz'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(syncServiceProvider).setSharedFounder(shared);
      if (mounted) setState(() => _error = null);
    } on LastPersonalAdminException {
      if (mounted) {
        setState(() => _error =
            'Najpierw nadaj uprawnienia administratora komuś na jego własnym '
            'koncie — to on będzie zarządzał jednostką.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się zmienić: $e');
    }
  }

  Future<void> _revoke(UnitMemberAccess member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odbierz dostęp'),
        content: Text(
          '${member.email} straci dostęp do danych jednostki. '
          'Dane już pobrane na jego telefon pozostaną tam, ale nie będzie '
          'ich dalej synchronizować.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: OspTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odbierz'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(syncServiceProvider).revokeMember(member);
      await _loadMembers();
    } on LastPersonalAdminException catch (e) {
      if (mounted) setState(() => _error = '$e');
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się odebrać: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final onServer = ref.watch(syncServiceProvider).onServer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Członkowie jednostki',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          onServer
              ? 'Zanim ktoś dołączy kodem, musi być na liście zaproszonych '
                  'ze swoim adresem — samo podanie kodu nie wystarczy. Kod '
                  'wysyłasz sam: SMS-em, komunikatorem albo e-mailem.'
              : 'Zanim ktoś dołączy kodem, musi dostać zaproszenie na swój '
                  'adres — samo podanie kodu nie wystarczy. Razem '
                  'z zaproszeniem Google wysyła e-mail z kodem.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (syncState.rejectedChanges.isNotEmpty) ...[
          RejectedChangesCard(
            changes: syncState.rejectedChanges,
            onClear: () =>
                ref.read(syncServiceProvider).clearRejectedChanges(),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _loading ? null : _invite,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Zaproś do jednostki'),
        ),
        if (syncState.founderEmail != null) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: syncState.sharedFounder,
            onChanged: _loading ? null : _toggleShared,
            title: const Text('Konto jednostki jest wspólne'),
            subtitle: Text(
              'Np. tablet w samochodzie. ${syncState.founderEmail} działa '
              'wtedy jak zwykły członek, a przy wpisach pyta, kto wpisuje.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: () => showSharedAccountGuide(context),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Tablet w samochodzie — krok po kroku'),
          ),
        ],
        const SizedBox(height: 8),
        if (_members == null)
          TextButton.icon(
            onPressed: _loading ? null : _loadMembers,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.group, size: 18),
            label: Text(onServer ? 'Pokaż członków' : 'Pokaż, kto ma dostęp'),
          )
        else ...[
          for (final m in _members!)
            _MemberTile(
              member: m,
              isFounder: syncState.isFounder(m.email),
              sharedAccount:
                  syncState.isFounder(m.email) && syncState.sharedFounder,
              isAdmin: syncState.isAdmin(m.email),
              isMe: (syncState.userEmail ?? '').trim().toLowerCase() ==
                  m.email.trim().toLowerCase(),
              note: _notes[m.email.trim().toLowerCase()],
              onServer: onServer,
              onToggleAdmin: (v) => _toggleAdmin(m, v),
              onRevoke: () => _revoke(m),
            ),
          TextButton.icon(
            onPressed: _loading ? null : _loadMembers,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Odśwież listę'),
          ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UnitMemberAccess member;
  final bool isFounder;

  /// Założyciel z włączonym wspólnym kontem jednostki.
  final bool sharedAccount;
  final bool isAdmin;
  final bool isMe;

  /// Notatka z telefonu tej osoby — `null`, gdy jeszcze nie dołączyła albo
  /// ma wersję sprzed feature/080.
  final MemberNote? note;
  final ValueChanged<bool> onToggleAdmin;
  final VoidCallback onRevoke;

  /// Serwer jednostek: kto nie ma rekordu członka, ten jeszcze nie
  /// dołączył — bez zgadywania o starszej wersji (feature/081).
  final bool onServer;

  const _MemberTile({
    this.onServer = false,
    required this.member,
    required this.isFounder,
    this.sharedAccount = false,
    required this.isAdmin,
    required this.isMe,
    this.note,
    required this.onToggleAdmin,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    // Założyciel zawsze zostaje administratorem i nie da się go usunąć —
    // inaczej jednostka mogłaby zostać bez nikogo, kto może nią zarządzać.
    final locked = isFounder || member.isOwner;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.email + (isMe ? '  (Ty)' : ''),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sharedAccount
                        ? (isAdmin
                            ? 'Wspólne konto — administrator, dopóki nikt '
                                'inny nim nie jest'
                            : 'Wspólne konto jednostki — jak zwykły członek')
                        : locked
                            ? 'Założyciel — stały administrator'
                            : (isAdmin ? 'Administrator' : 'Użytkownik'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onServer && member.invited
                        ? 'Zaproszony — jeszcze nie dołączył'
                        : memberStatus(note, DateTime.now()),
                    style: TextStyle(
                      fontSize: 12,
                      color: note == null
                          ? OspTheme.attention
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (!locked) ...[
              Tooltip(
                message: 'Uprawnienia administratora',
                child: Switch(
                  value: isAdmin,
                  onChanged: onToggleAdmin,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_remove_outlined,
                    color: OspTheme.danger),
                tooltip: 'Odbierz dostęp',
                onPressed: onRevoke,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zmiany na Dysku, których telefon nie przyjął (fix/067): ktoś zmienił
/// pliki jednostki na drive.google.com, choć w aplikacji nie mógłby.
class RejectedChangesCard extends StatelessWidget {
  final List<RejectedChange> changes;
  final VoidCallback onClear;

  const RejectedChangesCard({
    super.key,
    required this.changes,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OspTheme.attention.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OspTheme.attention.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gpp_maybe, color: OspTheme.attention, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Zmiany z pominięciem aplikacji',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ktoś zmienił pliki jednostki bezpośrednio na Dysku Google, '
            'choć w aplikacji nie ma do tego uprawnień. Telefony tych zmian '
            'nie przyjęły.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${c.what} — ${c.by}, ${TimeFormat.date(c.at)} '
                '${TimeFormat.hhmm(c.at)}'
                '${c.restored ? ' · przywrócone' : ''}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Jeśli to nie pomyłka, odbierz tej osobie dostęp na liście '
            'poniżej.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClear,
              child: const Text('Rozumiem, wyczyść'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okno „Zaproś strażaka" — z własnym polem adresu.
///
/// Pole zwalnia okno dopiero po zamknięciu. Wcześniej ekran zwalniał je
/// zaraz po wybraniu przycisku, a okno w trakcie znikania jeszcze z niego
/// korzystało (test z feature/068 wykrył błąd „used after being disposed").
class _InviteDialog extends StatefulWidget {
  final bool onServer;
  const _InviteDialog({this.onServer = false});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zaproś do jednostki'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.onServer
                ? 'Podaj adres e-mail, którym ta osoba loguje się '
                    'w aplikacji. Trafi na listę zaproszonych, a kod '
                    'zaproszenia wyślesz jej w następnym kroku.'
                : 'Podaj adres konta Google, którym ta osoba loguje się '
                    'w aplikacji. Dostanie dostęp do danych jednostki '
                    'i e-mail od Google z kodem zaproszenia i instrukcją '
                    'dołączenia.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.onServer ? 'Adres e-mail' : 'Adres e-mail (Gmail)',
              hintText: 'np. jan.kowalski@gmail.com',
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Zaproś'),
        ),
      ],
    );
  }
}

/// Czy i kiedy osoba z dostępem naprawdę dołączyła (feature/080), np.
/// „W aplikacji od 25.11.2026 · ostatnio dziś 14:05 · wersja 1.9.20".
///
/// Bez notatki nie da się odróżnić „nie przyjęła zaproszenia" od „ma wersję
/// sprzed tej funkcji" — napis mówi o obu, bez zgadywania.
@visibleForTesting
String memberStatus(MemberNote? note, DateTime now) {
  if (note == null) {
    return 'Brak śladu w aplikacji — zaproszenie nieprzyjęte albo starsza '
        'wersja aplikacji';
  }
  final parts = <String>[
    if (note.joinedAt != null) 'W aplikacji od ${TimeFormat.date(note.joinedAt!)}',
    if (note.lastSyncAt != null) 'ostatnio ${_when(note.lastSyncAt!, now)}',
    if (note.appVersion.isNotEmpty) 'wersja ${note.appVersion}',
  ];
  return parts.isEmpty ? 'W aplikacji' : parts.join(' · ');
}

String _when(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'dziś ${TimeFormat.hhmm(at)}';
  if (days == 1) return 'wczoraj ${TimeFormat.hhmm(at)}';
  return TimeFormat.date(at);
}
