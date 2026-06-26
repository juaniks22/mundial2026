// lib/domain/usecases/get_all_viewing_statuses_usecase.dart

import '../entities/match.dart';
import '../ports/match_repository_port.dart';

class GetAllViewingStatusesUseCase {
  final MatchRepositoryPort _repository;

  GetAllViewingStatusesUseCase(this._repository);

  Future<Map<String, UserViewingStatus>> call() {
    return _repository.getAllViewingStatuses();
  }
}
