import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_only_notice.dart';
import '../../widgets/correction_request_dialog.dart';
import '../../core/theme/osp_theme.dart';

class FirefightersScreen extends ConsumerStatefulWidget {
  const FirefightersScreen({super.key});

  @override
  ConsumerState<FirefightersScreen> createState() =>
      _FirefightersScreenState();
}

class _FirefightersScreenState extends ConsumerState<FirefightersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFirefighters = ref.watch(firefightersProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final syncState = ref.watch(syncStateProvider);
    final query = _searchQuery.trim().toLowerCase();
    // Kolejność „Nazwisko Imię" — tak zgłaszamy skład telefonicznie,
    // więc i szukamy, i sortujemy po nazwisku.
    final filtered = (query.isEmpty
        ? [...allFirefighters]
        : allFirefighters
            .where((f) => f.lastNameFirst.toLowerCase().contains(query))
            .toList())
      ..sort((a, b) => a.lastNameFirst
          .toLowerCase()
          .compareTo(b.lastNameFirst.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratownicy'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/firefighters/add'),
              icon: const Icon(Icons.person_add),
              label: const Text('Dodaj'),
            )
          : null,
      body: Column(
        children: [
          if (!isAdmin)
            AdminOnlyNotice(
              what: 'Listę ratowników',
              adminEmail: syncState.founderEmail,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Szukaj ratownika...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Brak ratowników'
                              : 'Nie znaleziono ratowników',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: 80 + context.bottomInset()),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ff = filtered[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: OspTheme.sectionFirefighters,
                            child: Text(
                              ff.firstName.isNotEmpty
                                  ? ff.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            ff.lastNameFirst,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: _buildFirefighterSubtitle(context, ff),
                          trailing: !isAdmin
                              ? IconButton(
                                  icon: Icon(Icons.flag_outlined,
                                      color: Colors.blueGrey[600]),
                                  onPressed: () =>
                                      _reportCorrection(context, ref, ff),
                                  tooltip: 'Zgłoś poprawkę do administratora',
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: OspTheme.info),
                                      onPressed: () => context
                                          .push('/firefighters/edit/${ff.id}'),
                                      tooltip: 'Edytuj',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: OspTheme.danger),
                                      onPressed: () => _confirmDelete(context,
                                          ref, ff.id, ff.lastNameFirst),
                                      tooltip: 'Usuń',
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirefighterSubtitle(BuildContext context, Firefighter ff) {
    final subtitleParts = <String>[ff.rank];

    if (ff.isMedicalExamExpired) {
      subtitleParts.add('Brak ważnych badań lekarskich');
    } else if (ff.isMedicalExamExpiringSoon) {
      final daysUntilExpiry = ff.medicalExamExpiry!
          .difference(DateTime.now())
          .inDays;
      subtitleParts.add('Badania lekarskie wygasną w ciągu $daysUntilExpiry dni');
    } else if (ff.hasMedicalExam) {
      subtitleParts.add('Ważne badania lekarskie');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRoleIcons(context, ff),
        if (subtitleParts.join(' • ').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitleParts.join(' • '),
              style: TextStyle(
                fontSize: 13,
                color: ff.isMedicalExamExpired || ff.isMedicalExamExpiringSoon
                    ? Colors.orange[700]
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleIcons(BuildContext context, Firefighter ff) {
    final icons = <Widget>[];

    // Kierowca, dowódca i KPP to dodatkowe uprawnienia — kto nie ma
    // żadnego, jest po prostu ratownikiem i tak też go oznaczamy, zamiast
    // zostawiać wiersz bez żadnej informacji o funkcji.
    if (!ff.isDriver && !ff.isCommander && !ff.isKPP) {
      icons.add(_roleIcon(
        context,
        Icons.person,
        'Ratownik',
        'Ratownik: bez dodatkowych uprawnień (kierowca, dowódca, KPP).',
      ));
    }

    if (ff.isDriver) {
      icons.add(_roleIcon(
        context,
        Icons.drive_eta,
        'Kierowca',
        'Kierowca: posiada uprawnienia kierowcy pojazdu pożarniczego.',
      ));
    }
    if (ff.isCommander) {
      icons.add(_roleIcon(
        context,
        Icons.military_tech,
        'Dowódca',
        'Dowódca: może pełnić funkcję dowódcy zastępu.',
      ));
    }
    if (ff.isKPP) {
      icons.add(_roleIcon(
        context,
        Icons.medical_services,
        'Ratownik medyczny',
        'KPP: posiada kwalifikowaną pierwszą pomoc.',
      ));
    }

    if (ff.isMedicalExamExpired) {
      icons.add(_roleIcon(
        context,
        Icons.error_outline,
        'Badania wygasły',
        'Badania lekarskie są nieważne.',
        color: OspTheme.danger,
      ));
    } else if (ff.isMedicalExamExpiringSoon) {
      icons.add(_roleIcon(
        context,
        Icons.warning_amber,
        'Badania wkrótce wygasną',
        'Badania lekarskie wygasną w ciągu 30 dni.',
        color: Colors.orange,
      ));
    } else if (ff.hasMedicalExam) {
      icons.add(_roleIcon(
        context,
        Icons.check_circle,
        'Ważne badania lekarskie',
        'Badania lekarskie są ważne.',
        color: OspTheme.success,
      ));
    } else if (!ff.hasMedicalExam) {
      icons.add(_roleIcon(
        context,
        Icons.help_outline,
        'Brak daty badań',
        'Nie ustawiono daty ważności badań lekarskich.',
        color: Colors.grey,
      ));
    }

    if (icons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: icons,
      ),
    );
  }

  Widget _roleIcon(
    BuildContext context,
    IconData icon,
    String tooltip,
    String explanation, {
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(explanation),
                duration: const Duration(seconds: 2),
              ),
            );
        },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Zwykły użytkownik nie edytuje danych ratowników, ale może zgłosić
  /// administratorowi, że coś się nie zgadza — np. literówkę w nazwisku
  /// albo nieaktualny termin badań.
  void _reportCorrection(
      BuildContext context, WidgetRef ref, Firefighter ff) {
    final syncState = ref.read(syncStateProvider);
    showCorrectionRequestDialog(
      context: context,
      firefighter: ff,
      adminEmail: syncState.founderEmail,
      reporterEmail: syncState.userEmail,
      unitName: ref.read(unitConfigProvider).fullName,
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń ratownika'),
        content: Text('Czy na pewno chcesz usunąć "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OspTheme.danger,
            ),
            onPressed: () {
              ref.read(firefightersProvider.notifier).delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
