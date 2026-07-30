import 'package:flutter/material.dart';

/// Informacja, że dana część aplikacji jest zastrzeżona dla administratora
/// jednostki.
///
/// Pokazujemy ją zamiast ukrywać przyciski — dzięki temu widać, że funkcja
/// istnieje, i wiadomo, do kogo się zwrócić, zamiast zastanawiać się,
/// czemu czegoś nie ma.
class AdminOnlyNotice extends StatelessWidget {
  /// Czego dotyczy blokada, np. „Listę pojazdów".
  final String what;

  /// Adres administratora, jeśli znany — pomaga wiedzieć, kogo prosić.
  final String? adminEmail;

  const AdminOnlyNotice({super.key, required this.what, this.adminEmail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.blueGrey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$what może zmieniać tylko administrator jednostki.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (adminEmail != null && adminEmail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Administrator: $adminEmail',
                    style: TextStyle(
                        fontSize: 12, color: Colors.blueGrey[700]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
