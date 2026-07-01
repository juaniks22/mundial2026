import 'package:mundial2026/domain/entities/match.dart';
import 'package:mundial2026/core/errors/app_exception.dart';
import 'package:mundial2026/domain/entities/standing.dart';

/// Resultado tipado: éxito con valor T o falla con AppException.
/// Evita usar Exceptions como control de flujo en los providers.
typedef Result<T> = ({T data, AppException? error});

abstract class MatchRepositoryPort {
  /// Devuelve todos los partidos del Mundial 2026.
  ///
  /// Devuelve todos los partidos del Mundial desde la API.
  /// Lanza [NetworkException] o [RateLimitException] en caso de error.
  Future<List<Match>> fetchMatches();

  /// Obtiene todos los partidos, usando estrategia híbrida (cache + remote).
  Future<List<Match>> matches();

  /// Actualiza el estado personal de un partido.
  Future<void> updateViewingStatus(String matchId, UserViewingStatus status);

  /// Fuerza una recarga desde la API, ignorando el cache.
  Future<List<Match>> forceRefresh();

  /// Obtiene todos los estados de visualización personal almacenados en Hive.
  Future<Map<String, UserViewingStatus>> getAllViewingStatuses();

  /// Actualiza si el usuario vio el alargue de un partido eliminatorio.
  Future<void> updateExtraTimeStatus(String matchId, bool watched);

  /// Obtiene todos los estados de alargue almacenados.
  Future<Map<String, bool>> getAllExtraTimeStatuses();

  /// Obtiene las tablas de posiciones de todos los grupos del torneo.
  Future<List<GroupStanding>> getStandings();
}

