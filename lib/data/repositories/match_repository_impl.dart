// lib/data/repositories/match_repository_impl.dart
//
// Implementación concreta del puerto MatchRepositoryPort.
// Es el corazón de la arquitectura híbrida:
//   - Para leer datos: API → merge con statuses locales → cache
//   - Para estado personal: solo Hive (no toca la API)
//
// Estrategia "stale-while-revalidate":
//   1. Si hay caché válido → emite datos locales inmediatamente.
//   2. Siempre intenta fetch remoto en segundo plano.
//   3. Si el fetch falla y hay caché → usa caché silenciosamente.
//   4. Si el fetch falla y no hay caché → propaga el error.

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/match.dart';
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
    // ¿El caché está vigente?
    if (!_local.isCacheStale(ApiConstants.cacheMaxAge)) {
      final cached = _local.readCachedMatches();
      if (cached != null) {
        return _mergeWithLocalStatuses(cached);
      }
    }

    // Caché expirado o inexistente → fetch remoto
    return _fetchAndCache();
  }

  @override
  Future<List<Match>> forceRefresh() => _fetchAndCache();

  // ─────────────────────────────────────────────────────────────────────────
  // Actualización del estado personal
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> updateViewingStatus(
    String matchId,
    UserViewingStatus status,
  ) async {
    await _local.saveViewingStatus(matchId, status);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Match>> _fetchAndCache() async {
    try {
      final remoteMatches = await _remote.fetchMatches();
      final merged = _mergeWithLocalStatuses(remoteMatches);

      // Guardamos en caché los datos de la API (sin user statuses,
      // ya que esos se leen dinámicamente desde statusBox).
      await _local.cacheMatches(remoteMatches);

      return merged;
    } on AppException {
      // Si el fetch falla pero tenemos caché (aunque esté stale), lo usamos.
      final staleCache = _local.readCachedMatches();
      if (staleCache != null) {
        return _mergeWithLocalStatuses(staleCache);
      }
      // Sin caché y sin red → propagamos el error al provider.
      rethrow;
    }
  }

  /// Combina la lista de partidos con los estados personales del usuario.
  /// El estado local tiene siempre precedencia sobre el dato de la API
  /// (que nunca incluye userViewingStatus).
  List<Match> _mergeWithLocalStatuses(List<Match> apiMatches) {
    final statuses = _local.readAllViewingStatuses();
    return apiMatches.map((match) {
      final localStatus = statuses[match.id] ?? UserViewingStatus.notWatched;
      return match.copyWith(userViewingStatus: localStatus);
    }).toList();
  }
}
