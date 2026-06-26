// lib/domain/usecases/force_refresh_matches_usecase.dart

import '../entities/match.dart';
import '../ports/match_repository_port.dart';

class ForceRefreshMatchesUseCase {
  final MatchRepositoryPort _repository;

  ForceRefreshMatchesUseCase(this._repository);

  Future<List<Match>> call() {
    return _repository.forceRefresh();
  }
}
