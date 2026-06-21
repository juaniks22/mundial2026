// lib/core/errors/app_exception.dart

/// Excepción base del dominio.
/// Todas las fallas de la app extienden de esta clase.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Fallo al conectarse a la API remota.
class NetworkException extends AppException {
  final int? statusCode;
  const NetworkException(super.message, {this.statusCode, super.cause});
}

/// Fallo al leer o escribir en el almacenamiento local Hive.
class CacheException extends AppException {
  const CacheException(super.message, {super.cause});
}

/// La API no devolvió datos para el Mundial 2026 (competition not found, etc).
class NoDataException extends AppException {
  const NoDataException(super.message, {super.cause});
}

/// El rate limit de la API gratuita fue alcanzado (10 req/min).
class RateLimitException extends AppException {
  const RateLimitException()
      : super('Límite de requests alcanzado. Esperá un momento.');
}
