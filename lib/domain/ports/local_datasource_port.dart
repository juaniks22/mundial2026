// lib/domain/ports/local_datasource_port.dart

import '../entities/match.dart';

abstract class LocalDataSourcePort {
  // ── Estado personal ─────────────────────────────────────────────────────

  /// Guarda el estado de visualización personal para un partido.
  Future<void> saveViewingStatus(String matchId, UserViewingStatus status);

  /// Lee el estado de visualización. Retorna [UserViewingStatus.notWatched]
  /// si no existe entrada previa (comportamiento por defecto seguro).
  UserViewingStatus readViewingStatus(String matchId);

  /// Lee todos los estados guardados como Map<matchId, UserViewingStatus>.
  Map<String, UserViewingStatus> readAllViewingStatuses();

  // ── Caché del fixture ────────────────────────────────────────────────────

  /// Guarda la lista completa de partidos como JSON serializado.
  Future<void> cacheMatches(List<Match> matches);

  /// Lee el fixture desde cache. Retorna null si no hay datos.
  List<Match>? readCachedMatches();

  /// Retorna cuándo fue el último sincronizado. Null si nunca.
  DateTime? lastSyncedAt();

  /// Indica si el cache expiró según [maxAge].
  bool isCacheStale(Duration maxAge);
}
