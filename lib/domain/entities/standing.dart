// lib/domain/entities/standing.dart
//
// Entidad que representa la clasificación de un equipo
// en la tabla de grupos del Mundial 2026.

class GroupStanding {
  final String group;         // "GROUP_A", "GROUP_B", etc.
  final int position;         // 1, 2, 3, 4
  final String teamId;
  final String teamName;
  final String tla;           // "ARG", "BRA", etc.
  final String? crestUrl;
  final int playedGames;
  final int won;
  final int draw;
  final int lost;
  final int points;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;

  const GroupStanding({
    required this.group,
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.tla,
    this.crestUrl,
    required this.playedGames,
    required this.won,
    required this.draw,
    required this.lost,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
  });

  /// Nombre del grupo legible: "GROUP_A" → "Grupo A"
  String get groupLabel {
    final letter = group.replaceFirst('GROUP_', '');
    return 'Grupo $letter';
  }
}
