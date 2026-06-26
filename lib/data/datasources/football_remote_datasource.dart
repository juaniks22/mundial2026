// lib/data/datasources/football_remote_datasource.dart
//
// Adaptador concreto del puerto RemoteDataSourcePort.
// Sabe cómo hablar con football-data.org v4 y transformar
// la respuesta en entidades de dominio.

import 'package:dio/dio.dart';
import 'package:mundial2026/core/constants/api_constants.dart';
import 'package:mundial2026/core/errors/app_exception.dart';
import 'package:mundial2026/domain/entities/match.dart';
import 'package:mundial2026/data/models/match_model.dart';
import 'package:mundial2026/domain/entities/standing.dart';
import 'package:mundial2026/domain/ports/remote_datasource_port.dart';

class FootballRemoteDataSource implements RemoteDataSourcePort {
  final Dio _dio;

  FootballRemoteDataSource(this._dio);

  // ─────────────────────────────────────────────────────────────────────────
  // Partidos
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<Match>> fetchMatches() async {
    try {
      final response = await _dio.get(
        ApiConstants.matchesEndpoint,
        options: Options(headers: ApiConstants.headers),
      );

      if (response.statusCode == 200) {
        return _parseMatches(response.data as Map<String, dynamic>);
      }

      throw NetworkException(
        'Error inesperado del servidor',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Standings (tablas de grupo)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<GroupStanding>> fetchStandings() async {
    try {
      final response = await _dio.get(
        ApiConstants.standingsEndpoint,
        options: Options(headers: ApiConstants.headers),
      );

      if (response.statusCode == 200) {
        return _parseStandings(response.data as Map<String, dynamic>);
      }

      throw NetworkException(
        'Error inesperado del servidor (standings)',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Parseo privado
  // ─────────────────────────────────────────────────────────────────────────

  List<Match> _parseMatches(Map<String, dynamic> json) {
    final matchesJson = json['matches'] as List<dynamic>?;
    if (matchesJson == null) {
      throw const NoDataException(
        'La API no devolvió partidos. '
        'Verificá que el Mundial 2026 esté disponible en tu plan.',
      );
    }

    return matchesJson
        .map((m) => MatchSerialization.fromFootballDataJson(m as Map<String, dynamic>))
        .toList();
  }

  List<GroupStanding> _parseStandings(Map<String, dynamic> json) {
    final standingsJson = json['standings'] as List<dynamic>? ?? [];
    final result = <GroupStanding>[];

    for (final groupJson in standingsJson) {
      final group = groupJson as Map<String, dynamic>;
      final groupName = group['group'] as String? ??
          group['stage'] as String? ??
          'UNKNOWN';
      final tableJson = group['table'] as List<dynamic>? ?? [];

      for (final entryJson in tableJson) {
        final entry = entryJson as Map<String, dynamic>;
        final teamJson = entry['team'] as Map<String, dynamic>? ?? {};

        result.add(GroupStanding(
          group: groupName,
          position: entry['position'] as int? ?? 0,
          teamId: teamJson['id']?.toString() ?? '0',
          teamName: teamJson['name'] as String? ?? 'TBD',
          tla: teamJson['tla'] as String? ?? '???',
          crestUrl: teamJson['crest'] as String?,
          playedGames: entry['playedGames'] as int? ?? 0,
          won: entry['won'] as int? ?? 0,
          draw: entry['draw'] as int? ?? 0,
          lost: entry['lost'] as int? ?? 0,
          points: entry['points'] as int? ?? 0,
          goalsFor: entry['goalsFor'] as int? ?? 0,
          goalsAgainst: entry['goalsAgainst'] as int? ?? 0,
          goalDifference: entry['goalDifference'] as int? ?? 0,
        ));
      }
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mapeo de errores Dio → AppException
  // ─────────────────────────────────────────────────────────────────────────

  AppException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException(
          'Tiempo de conexión agotado. Verificá tu internet.',
          cause: e,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          'Sin conexión. Revisá tu red.',
          cause: e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 429) return const RateLimitException();
        if (statusCode == 401 || statusCode == 403) {
          return NetworkException(
            'API key inválida o sin permisos. '
            'Verificá tu key en football-data.org',
            statusCode: statusCode,
          );
        }
        if (statusCode == 404) {
          return const NoDataException(
            'Competición no encontrada. '
            'El Mundial 2026 podría no estar disponible en tu plan gratuito.',
          );
        }
        return NetworkException(
          'Error del servidor: $statusCode',
          statusCode: statusCode,
          cause: e,
        );

      default:
        return NetworkException('Error de red desconocido.', cause: e);
    }
  }
}

/// Factory que configura Dio con los defaults del proyecto.
Dio createDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
}
