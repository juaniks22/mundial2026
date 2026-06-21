// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.football-data.org/v4';

  /// Obtené tu key gratuita en https://www.football-data.org/client/register
  static const String apiKey = 'a5293dba45b541dcb7163e20dd52c8dd';

  /// Código de competición del Mundial FIFA
  static const String worldCupCode = 'WC';

  /// Headers requeridos por football-data.org
  static const Map<String, String> headers = {
    'X-Auth-Token': apiKey,
  };

  /// Endpoints
  static const String matchesEndpoint =
      '$baseUrl/competitions/$worldCupCode/matches';

  /// Duración máxima antes de considerar el caché desactualizado.
  /// Para partidos en vivo usamos menos tiempo.
  static const Duration cacheMaxAge = Duration(minutes: 5);
  static const Duration liveCacheMaxAge = Duration(seconds: 30);
}

class HiveConstants {
  HiveConstants._();

  /// Box donde se guarda el estado personal de cada partido.
  /// Key: matchId (String) → Value: índice del enum UserViewingStatus (int)
  static const String statusBox = 'user_viewing_status';

  /// Box donde se cachea el fixture completo como JSON.
  /// Key: 'matches' → Value: JSON string
  /// Key: 'last_synced' → Value: ISO 8601 string del último fetch
  static const String cacheBox = 'match_cache';

  static const String cacheMatchesKey = 'matches';
  static const String cacheTimestampKey = 'last_synced';
}
