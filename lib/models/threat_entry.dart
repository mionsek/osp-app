import 'package:hive/hive.dart';

part 'threat_entry.g.dart';

@HiveType(typeId: 3)
class ThreatEntry extends HiveObject {
  @HiveField(0)
  String category;

  @HiveField(1)
  List<String> subtypes;

  @HiveField(2)
  bool isCustom;

  ThreatEntry({
    required this.category,
    List<String>? subtypes,
    this.isCustom = false,
  }) : subtypes = subtypes ?? [];
}
