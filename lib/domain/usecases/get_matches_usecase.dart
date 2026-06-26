// lib/domain/usecases/get_matches_usecase.dart

import '../entities/match.dart';
import '../ports/match_repository_port.dart';

class GetMatchesUseCase {
  final MatchRepositoryPort _repository;

  GetMatchesUseCase(this._repository);

  Future<List<Match>> call() {
    return _repository.matches();
  }
}
