// lib/domain/entities/match.dart
//
// Mapeado al formato real de football-data.org v4:
// GET /v4/competitions/WC/matches
// ─────────────────────────────────────────────────────────────────────────


// ═══════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════

/// Estado de visualización PERSONAL del usuario.
/// Se persiste en Hive y es independiente del estado real del partido.
enum UserViewingStatus {
  notWatched,  // 🔴 No visto  (default)
  halfTime,    // 🟡 Hasta el medio tiempo
  watched,     // 🟢 Visto completo
  summary,     // 🔵 Vi el resumen
}

/// Estado oficial del partido según la API de football-data.org.
enum MatchStatus {
  scheduled,   // SCHEDULED / TIMED — Programado
  live,        // IN_PLAY / PAUSED — En vivo o en descanso
  finished,    // FINISHED
  postponed,   // POSTPONED
  cancelled,   // CANCELLED / SUSPENDED
}

/// Fase del torneo.
enum MatchStage {
  groupStage,
  roundOf32,
  roundOf16,
  quarterFinal,
  semiFinal,
  thirdPlace,
  final_,
  unknown,
}

// ═══════════════════════════════════════════════════════════════════════════
// VALUE OBJECTS
// ═══════════════════════════════════════════════════════════════════════════

/// Equipo participante. El campo [goals] viene del objeto score de la API,
/// no del bloque homeTeam/awayTeam directamente.
class Team {
  final String id;
  final String name;
  final String shortName;
  final String tla;          // Ej: "ARG", "BRA"
  final String? crestUrl;   // SVG en football-data.org
  final int? goals;         // Inyectado desde score.fullTime

  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tla,
    this.crestUrl,
    this.goals,
  });



  Team copyWith({int? goals}) => Team(
    id: id,
    name: name,
    shortName: shortName,
    tla: tla,
    crestUrl: crestUrl,
    goals: goals ?? this.goals,
  );
}

/// Resultado del partido (del bloque score de la API).
class Score {
  final int? homeGoals;
  final int? awayGoals;
  final int? homeHalfTimeGoals;
  final int? awayHalfTimeGoals;
  final String? winner; // "HOME_TEAM" | "AWAY_TEAM" | "DRAW" | null

  const Score({
    this.homeGoals,
    this.awayGoals,
    this.homeHalfTimeGoals,
    this.awayHalfTimeGoals,
    this.winner,
  });



  /// Retorna "2-1" o null si no hay datos de score.
  String? get scoreline {
    if (homeGoals == null || awayGoals == null) return null;
    return '$homeGoals-$awayGoals';
  }

  bool get hasScore => homeGoals != null && awayGoals != null;
}

// ═══════════════════════════════════════════════════════════════════════════
// ENTIDAD PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

/// Partido del Mundial 2026.
///
/// Combina:
/// - Datos REMOTOS de football-data.org (status, teams, score, venue, etc.)
/// - Estado PERSONAL LOCAL del usuario ([userViewingStatus]) persistido en Hive.
class Match {
  // Identificador único de la API — sirve como clave para Hive.
  final String id;
  final DateTime utcDate;
  final MatchStatus status;
  final MatchStage stage;
  final String? group;        // "GROUP_A", "GROUP_B", ..., null para fase KO
  final int? matchday;

  // Equipos
  final Team homeTeam;
  final Team awayTeam;

  // Resultado
  final Score score;

  // Detalles adicionales
  final String? venue;
  final String? refereeMain;
  final DateTime lastUpdated;

  // ── ESTADO PERSONAL (local, NO viene de la API) ──────────────────────────
  final UserViewingStatus userViewingStatus;
  final bool watchedExtraTime;
  final DateTime? userStatusUpdatedAt;

  const Match({
    required this.id,
    required this.utcDate,
    required this.status,
    required this.stage,
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
    required this.lastUpdated,
    this.group,
    this.matchday,
    this.venue,
    this.refereeMain,
    this.userViewingStatus = UserViewingStatus.notWatched,
    this.watchedExtraTime = false,
    this.userStatusUpdatedAt,
  });



  // ───────────────────────────────────────────────────────────────────────
  // copyWith — para actualizar el estado personal sin mutar el objeto
  // ───────────────────────────────────────────────────────────────────────
  Match copyWith({
    MatchStatus? status,
    Score? score,
    Team? homeTeam,
    Team? awayTeam,
    UserViewingStatus? userViewingStatus,
    bool? watchedExtraTime,
    DateTime? userStatusUpdatedAt,
  }) {
    return Match(
      id: id,
      utcDate: utcDate,
      status: status ?? this.status,
      stage: stage,
      group: group,
      matchday: matchday,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      score: score ?? this.score,
      venue: venue,
      refereeMain: refereeMain,
      lastUpdated: lastUpdated,
      userViewingStatus: userViewingStatus ?? this.userViewingStatus,
      watchedExtraTime: watchedExtraTime ?? this.watchedExtraTime,
      userStatusUpdatedAt: userStatusUpdatedAt ?? this.userStatusUpdatedAt,
    );
  }

  @override
  String toString() =>
      '${homeTeam.tla} vs ${awayTeam.tla} | ${score.scoreline ?? status.name}';
}



// ═══════════════════════════════════════════════════════════════════════════
// EXTENSIONES UTILITARIAS
// ═══════════════════════════════════════════════════════════════════════════

extension UserViewingStatusX on UserViewingStatus {
  String get emoji {
    switch (this) {
      case UserViewingStatus.notWatched: return '🔴';
      case UserViewingStatus.halfTime:   return '🟡';
      case UserViewingStatus.watched:    return '🟢';
      case UserViewingStatus.summary:    return '🔵';
    }
  }

  String get label {
    switch (this) {
      case UserViewingStatus.notWatched: return 'No visto';
      case UserViewingStatus.halfTime:   return 'Medio tiempo';
      case UserViewingStatus.watched:    return 'Visto';
      case UserViewingStatus.summary:    return 'Resumen';
    }
  }
}

extension MatchStatusX on MatchStatus {
  String get label {
    switch (this) {
      case MatchStatus.scheduled: return 'Programado';
      case MatchStatus.live:      return '🔴 En vivo';
      case MatchStatus.finished:  return 'Finalizado';
      case MatchStatus.postponed: return 'Postergado';
      case MatchStatus.cancelled: return 'Cancelado';
    }
  }
}

extension MatchStageX on MatchStage {
  String get label {
    switch (this) {
      case MatchStage.groupStage:   return 'Fase de Grupos';
      case MatchStage.roundOf32:    return '16avos';
      case MatchStage.roundOf16:    return 'Octavos de Final';
      case MatchStage.quarterFinal: return 'Cuartos de Final';
      case MatchStage.semiFinal:    return 'Semifinales';
      case MatchStage.thirdPlace:   return 'Tercer Puesto';
      case MatchStage.final_:       return 'Final';
      case MatchStage.unknown:      return 'Sin clasificar';
    }
  }
}
