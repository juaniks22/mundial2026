// lib/domain/ports/remote_datasource_port.dart

import '../entities/match.dart';
import '../entities/standing.dart';

abstract class RemoteDataSourcePort {
  /// Obtiene todos los partidos del Mundial desde la API.
  /// Lanza [NetworkException] o [RateLimitException] en caso de error.
  Future<List<Match>> fetchMatches();

  /// Obtiene las tablas de posiciones de todos los grupos.
  Future<List<GroupStanding>> fetchStandings();
}
