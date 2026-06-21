// lib/domain/entities/match.dart
//
// Mapeado al formato real de football-data.org v4:
// GET /v4/competitions/WC/matches
// ─────────────────────────────────────────────────────────────────────────

import 'dart:convert';

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

  /// Parsea el bloque homeTeam/awayTeam de la API.
  /// [goals] se pasa externamente desde score.fullTime.home/away.
  factory Team.fromJson(Map<String, dynamic> json, {int? goals}) {
    return Team(
      id: json['id']?.toString() ?? '0',
      name: json['name'] as String? ?? 'TBD',
      shortName: json['shortName'] as String? ?? json['name'] as String? ?? 'TBD',
      tla: json['tla'] as String? ?? '???',
      crestUrl: json['crest'] as String?,
      goals: goals,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'tla': tla,
    'crest': crestUrl,
    'goals': goals,
  };

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

  factory Score.fromJson(Map<String, dynamic> json) {
    final fullTime = json['fullTime'] as Map<String, dynamic>? ?? {};
    final halfTime = json['halfTime'] as Map<String, dynamic>? ?? {};
    return Score(
      homeGoals: fullTime['home'] as int?,
      awayGoals: fullTime['away'] as int?,
      homeHalfTimeGoals: halfTime['home'] as int?,
      awayHalfTimeGoals: halfTime['away'] as int?,
      winner: json['winner'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'fullTime': {'home': homeGoals, 'away': awayGoals},
    'halfTime': {'home': homeHalfTimeGoals, 'away': awayHalfTimeGoals},
    'winner': winner,
  };

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
    this.userStatusUpdatedAt,
  });

  // ───────────────────────────────────────────────────────────────────────
  // FACTORY: desde respuesta real de football-data.org
  // ───────────────────────────────────────────────────────────────────────
  factory Match.fromFootballDataJson(
    Map<String, dynamic> json, {
    UserViewingStatus userStatus = UserViewingStatus.notWatched,
    DateTime? statusUpdatedAt,
  }) {
    final scoreData = Score.fromJson(json['score'] as Map<String, dynamic>? ?? {});

    final referees = (json['referees'] as List<dynamic>?) ?? [];
    final referee = referees.isNotEmpty
        ? (referees.first as Map<String, dynamic>)['name'] as String?
        : null;

    return Match(
      id: json['id'].toString(),
      utcDate: DateTime.parse(json['utcDate'] as String),
      status: _parseStatus(json['status'] as String? ?? 'SCHEDULED'),
      stage: _parseStage(json['stage'] as String? ?? ''),
      group: json['group'] as String?,
      matchday: json['matchday'] as int?,
      homeTeam: Team.fromJson(
        json['homeTeam'] as Map<String, dynamic>? ?? {},
        goals: scoreData.homeGoals,
      ),
      awayTeam: Team.fromJson(
        json['awayTeam'] as Map<String, dynamic>? ?? {},
        goals: scoreData.awayGoals,
      ),
      score: scoreData,
      venue: json['venue'] as String?,
      refereeMain: referee,
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
          DateTime.now(),
      userViewingStatus: userStatus,
      userStatusUpdatedAt: statusUpdatedAt,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN (para cache en Hive como JSON string)
  // ───────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'utcDate': utcDate.toIso8601String(),
    'status': status.name,
    'stage': stage.name,
    'group': group,
    'matchday': matchday,
    'homeTeam': homeTeam.toJson(),
    'awayTeam': awayTeam.toJson(),
    'score': score.toJson(),
    'venue': venue,
    'refereeMain': refereeMain,
    'lastUpdated': lastUpdated.toIso8601String(),
    'userViewingStatus': userViewingStatus.index,
    'userStatusUpdatedAt': userStatusUpdatedAt?.toIso8601String(),
  };

  factory Match.fromCacheJson(Map<String, dynamic> json) {
    final statusIndex = json['userViewingStatus'] as int? ?? 0;
    return Match(
      id: json['id'] as String,
      utcDate: DateTime.parse(json['utcDate'] as String),
      status: MatchStatus.values.byName(json['status'] as String? ?? 'scheduled'),
      stage: MatchStage.values.byName(json['stage'] as String? ?? 'unknown'),
      group: json['group'] as String?,
      matchday: json['matchday'] as int?,
      homeTeam: Team.fromJson(json['homeTeam'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(json['awayTeam'] as Map<String, dynamic>),
      score: Score.fromJson(json['score'] as Map<String, dynamic>),
      venue: json['venue'] as String?,
      refereeMain: json['refereeMain'] as String?,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      userViewingStatus: UserViewingStatus.values[
        statusIndex.clamp(0, UserViewingStatus.values.length - 1)
      ],
      userStatusUpdatedAt: json['userStatusUpdatedAt'] != null
          ? DateTime.parse(json['userStatusUpdatedAt'] as String)
          : null,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // copyWith — para actualizar el estado personal sin mutar el objeto
  // ───────────────────────────────────────────────────────────────────────
  Match copyWith({
    MatchStatus? status,
    Score? score,
    Team? homeTeam,
    Team? awayTeam,
    UserViewingStatus? userViewingStatus,
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
      userStatusUpdatedAt: userStatusUpdatedAt ?? this.userStatusUpdatedAt,
    );
  }

  @override
  String toString() =>
      '${homeTeam.tla} vs ${awayTeam.tla} | ${score.scoreline ?? status.name}';
}

// ═══════════════════════════════════════════════════════════════════════════
// PARSERS PRIVADOS
// ═══════════════════════════════════════════════════════════════════════════

MatchStatus _parseStatus(String raw) {
  switch (raw.toUpperCase()) {
    case 'IN_PLAY':
    case 'PAUSED':
      return MatchStatus.live;
    case 'FINISHED':
      return MatchStatus.finished;
    case 'POSTPONED':
      return MatchStatus.postponed;
    case 'CANCELLED':
    case 'SUSPENDED':
      return MatchStatus.cancelled;
    default:
      return MatchStatus.scheduled; // SCHEDULED, TIMED
  }
}

MatchStage _parseStage(String raw) {
  switch (raw.toUpperCase()) {
    case 'GROUP_STAGE':
      return MatchStage.groupStage;
    case 'LAST_32':
    case 'ROUND_OF_32':
      return MatchStage.roundOf32;
    case 'LAST_16':
    case 'ROUND_OF_16':
      return MatchStage.roundOf16;
    case 'QUARTER_FINAL':
    case 'QUARTER_FINALS':
      return MatchStage.quarterFinal;
    case 'SEMI_FINAL':
    case 'SEMI_FINALS':
      return MatchStage.semiFinal;
    case 'THIRD_PLACE':
      return MatchStage.thirdPlace;
    case 'FINAL':
      return MatchStage.final_;
    default:
      return MatchStage.unknown;
  }
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
      case MatchStage.roundOf32:    return 'Ronda de 32';
      case MatchStage.roundOf16:    return 'Octavos de Final';
      case MatchStage.quarterFinal: return 'Cuartos de Final';
      case MatchStage.semiFinal:    return 'Semifinales';
      case MatchStage.thirdPlace:   return 'Tercer Puesto';
      case MatchStage.final_:       return 'Final';
      case MatchStage.unknown:      return 'Sin clasificar';
    }
  }
}
