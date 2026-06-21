// lib/domain/ports/match_repository_port.dart
//
// Puerto principal que define el contrato del repositorio.
// La capa de presentación (Riverpod) solo depende de este puerto,
// nunca de la implementación concreta.
//
// Principio D de SOLID: el dominio depende de abstracciones.

import 'package:mundial2026/domain/entities/match.dart';
import 'package:mundial2026/core/errors/app_exception.dart';

/// Resultado tipado: éxito con valor T o falla con AppException.
/// Evita usar Exceptions como control de flujo en los providers.
typedef Result<T> = ({T data, AppException? error});

abstract class MatchRepositoryPort {
  /// Devuelve todos los partidos del Mundial 2026.
  ///
  /// Estrategia:
  /// 1. Emite cache local inmediatamente (si existe y es reciente).
  /// 2. Hace fetch a la API en background.
  /// 3. Fusiona user statuses con los datos remotos.
  /// 4. Emite la lista actualizada.
  ///
  /// Si no hay internet y existe cache → devuelve cache.
  /// Si no hay internet y no hay cache → lanza [NetworkException].
  Future<List<Match>> matches();

  /// Actualiza el [UserViewingStatus] de un partido específico.
  /// Se persiste en Hive. No toca la API.
  Future<void> updateViewingStatus(String matchId, UserViewingStatus status);

  /// Fuerza un re-fetch desde la API, ignorando el cache.
  Future<List<Match>> forceRefresh();
}
