import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/google_drive_service.dart';

/// Zarządzanie dostępem do jednostki: kto może z niej korzystać i kto ma
/// uprawnienia administratora.
///
/// Widoczne tylko dla administratora — zwykły użytkownik i tak nie mógłby
/// nic tu zmienić.
class UnitMembersSection extends ConsumerStatefulWidget {
  const UnitMembersSection({super.key});

  @override
  ConsumerState<UnitMembersSection> createState() =>
      _UnitMembersSectionState();
}

class _UnitMembersSectionState extends ConsumerState<UnitMembersSection> {
  List<UnitMemberAccess>? _members;
  bool _loading = false;
  String? _error;

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await ref.read(syncServiceProvider).listMembers();
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się pobrać listy: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zaproś strażaka'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podaj adres konta Google, którym kolega loguje się '
              'w aplikacji. Damy mu dostęp do danych jednostki, a potem '
              'wystarczy, że wpisze kod zaproszenia.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Adres e-mail (Gmail)',
                hintText: 'np. jan.kowalski@gmail.com',
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Zaproś'),
          ),
        ],
      ),
    );
    controller.dispose();
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
      await ref.read(syncServiceProvider).inviteMember(email);
      await _loadMembers();
      if (mounted) {
        final code = ref.read(syncStateProvider).unitInviteCode ?? '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Zaproszono $email. Przekaż mu kod: $code'),
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się zaprosić: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                backgroundColor: const Color(0xFFB71C1C)),
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
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się odebrać: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Członkowie jednostki',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Kolega musi mieć dostęp do danych jednostki, zanim dołączy '
          'kodem zaproszenia — samo podanie kodu nie wystarczy.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Text(_error!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _loading ? null : _invite,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Zaproś strażaka'),
        ),
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
            label: const Text('Pokaż, kto ma dostęp'),
          )
        else ...[
          for (final m in _members!)
            _MemberTile(
              member: m,
              isFounder: syncState.isFounder(m.email),
              isAdmin: syncState.isFounder(m.email) ||
                  syncState.adminEmails.any((e) =>
                      e.trim().toLowerCase() == m.email.trim().toLowerCase()),
              isMe: (syncState.userEmail ?? '').trim().toLowerCase() ==
                  m.email.trim().toLowerCase(),
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
  final bool isAdmin;
  final bool isMe;
  final ValueChanged<bool> onToggleAdmin;
  final VoidCallback onRevoke;

  const _MemberTile({
    required this.member,
    required this.isFounder,
    required this.isAdmin,
    required this.isMe,
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
                    locked
                        ? 'Założyciel — stały administrator'
                        : (isAdmin ? 'Administrator' : 'Użytkownik'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    color: Color(0xFFB71C1C)),
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
