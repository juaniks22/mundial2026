// lib/data/models/match_model.dart
//
// Extensiones de serialización y deserialización de datos para desacoplar el
// dominio (Entities) de los formatos de la API y de persistencia local (Hive).

import 'package:mundial2026/domain/entities/match.dart';

extension TeamSerialization on Team {
  static Team fromJson(Map<String, dynamic> json, {int? goals}) {
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
}

extension ScoreSerialization on Score {
  static Score fromJson(Map<String, dynamic> json) {
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
}

extension MatchSerialization on Match {
  static Match fromFootballDataJson(
    Map<String, dynamic> json, {
    UserViewingStatus userStatus = UserViewingStatus.notWatched,
    DateTime? statusUpdatedAt,
  }) {
    final scoreData = ScoreSerialization.fromJson(json['score'] as Map<String, dynamic>? ?? {});

    final referees = (json['referees'] as List<dynamic>?) ?? [];
    final referee = referees.isNotEmpty
        ? (referees.first as Map<String, dynamic>)['name'] as String?
        : null;

    return Match(
      id: json['id'].toString(),
      utcDate: DateTime.parse(json['utcDate'] as String),
      status: parseStatus(json['status'] as String? ?? 'SCHEDULED'),
      stage: parseStage(json['stage'] as String? ?? ''),
      group: json['group'] as String?,
      matchday: json['matchday'] as int?,
      homeTeam: TeamSerialization.fromJson(
        json['homeTeam'] as Map<String, dynamic>? ?? {},
        goals: scoreData.homeGoals,
      ),
      awayTeam: TeamSerialization.fromJson(
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

  static Match fromCacheJson(Map<String, dynamic> json) {
    final statusIndex = json['userViewingStatus'] as int? ?? 0;
    return Match(
      id: json['id'] as String,
      utcDate: DateTime.parse(json['utcDate'] as String),
      status: MatchStatus.values.byName(json['status'] as String? ?? 'scheduled'),
      stage: MatchStage.values.byName(json['stage'] as String? ?? 'unknown'),
      group: json['group'] as String?,
      matchday: json['matchday'] as int?,
      homeTeam: TeamSerialization.fromJson(json['homeTeam'] as Map<String, dynamic>),
      awayTeam: TeamSerialization.fromJson(json['awayTeam'] as Map<String, dynamic>),
      score: ScoreSerialization.fromJson(json['score'] as Map<String, dynamic>),
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
}

// ─────────────────────────────────────────────────────────────────────────
// PARSERS PRIVADOS
// ─────────────────────────────────────────────────────────────────────────

MatchStatus parseStatus(String raw) {
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

MatchStage parseStage(String raw) {
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
