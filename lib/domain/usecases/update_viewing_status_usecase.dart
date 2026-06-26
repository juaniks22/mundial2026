// lib/domain/usecases/update_viewing_status_usecase.dart

import '../entities/match.dart';
import '../ports/match_repository_port.dart';

class UpdateViewingStatusUseCase {
  final MatchRepositoryPort _repository;

  UpdateViewingStatusUseCase(this._repository);

  Future<void> call(String matchId, UserViewingStatus status) {
    return _repository.updateViewingStatus(matchId, status);
  }
}
