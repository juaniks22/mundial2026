// lib/domain/usecases/get_standings_usecase.dart
//
// Use case: obtiene las tablas de posiciones de todos los grupos.

import 'package:mundial2026/domain/entities/standing.dart';
import 'package:mundial2026/domain/ports/match_repository_port.dart';

class GetStandingsUseCase {
  final MatchRepositoryPort _repository;

  GetStandingsUseCase(this._repository);

  /// Retorna todos los GroupStanding de la competición.
  /// Solo los equipos en posición 3 de cada grupo son los "terceros".
  Future<List<GroupStanding>> call() => _repository.getStandings();

  /// Filtra y ordena los terceros de cada grupo según criterio FIFA:
  /// puntos → diferencia de gol → goles a favor.
  Future<List<GroupStanding>> getBestThirdPlace() async {
    final all = await _repository.getStandings();
    final thirds = all.where((s) => s.position == 3).toList();
    thirds.sort((a, b) {
      final pts = b.points.compareTo(a.points);
      if (pts != 0) return pts;
      final gd = b.goalDifference.compareTo(a.goalDifference);
      if (gd != 0) return gd;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return thirds;
  }
}
