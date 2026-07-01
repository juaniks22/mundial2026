// lib/data/repositories/match_repository_impl.dart
//
// Implementación concreta del puerto MatchRepositoryPort.
// Estrategia híbrida: cache + remote, con merge de estados locales.

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/standing.dart';
import '../../domain/ports/local_datasource_port.dart';
import '../../domain/ports/match_repository_port.dart';
import '../../domain/ports/remote_datasource_port.dart';

class MatchRepositoryImpl implements MatchRepositoryPort {
  final RemoteDataSourcePort _remote;
  final LocalDataSourcePort _local;

  MatchRepositoryImpl({
    required RemoteDataSourcePort remote,
    required LocalDataSourcePort local,
  })  : _remote = remote,
        _local = local;

  // ─────────────────────────────────────────────────────────────────────────
  // Lectura del fixture — estrategia híbrida
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<Match>> matches() async {
    if (!_local.isCacheStale(ApiConstants.cacheMaxAge)) {
      final cached = _local.readCachedMatches();
      if (cached != null) {
        return _mergeWithLocalStatuses(cached);
      }
    }
    return _fetchAndCache();
  }

  @override
  Future<List<Match>> forceRefresh() => _fetchAndCache();

  @override
  Future<List<Match>> fetchMatches() => _remote.fetchMatches();

  // ─────────────────────────────────────────────────────────────────────────
  // Estado personal del usuario
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> updateViewingStatus(
    String matchId,
    UserViewingStatus status,
  ) async {
    await _local.saveViewingStatus(matchId, status);
  }

  @override
  Future<Map<String, UserViewingStatus>> getAllViewingStatuses() async {
    return _local.readAllViewingStatuses();
  }

  @override
  Future<void> updateExtraTimeStatus(String matchId, bool watched) async {
    await _local.saveExtraTimeStatus(matchId, watched);
  }

  @override
  Future<Map<String, bool>> getAllExtraTimeStatuses() async {
    return _local.readAllExtraTimeStatuses();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Standings (tablas de grupo)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<GroupStanding>> getStandings() => _remote.fetchStandings();

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Match>> _fetchAndCache() async {
    try {
      final remoteMatches = await _remote.fetchMatches();
      final merged = _mergeWithLocalStatuses(remoteMatches);
      await _local.cacheMatches(remoteMatches);
      return merged;
    } on AppException {
      final staleCache = _local.readCachedMatches();
      if (staleCache != null) {
        return _mergeWithLocalStatuses(staleCache);
      }
      rethrow;
    }
  }

  List<Match> _mergeWithLocalStatuses(List<Match> apiMatches) {
    final statuses = _local.readAllViewingStatuses();
    final extraTimeStatuses = _local.readAllExtraTimeStatuses();
    return apiMatches.map((match) {
      final localStatus = statuses[match.id] ?? UserViewingStatus.notWatched;
      final extraTime = extraTimeStatuses[match.id] ?? false;
      return match.copyWith(
        userViewingStatus: localStatus,
        watchedExtraTime: extraTime,
      );
    }).toList();
  }
}
