// lib/presentation/providers/match_providers.dart
//
// Capa de state management — Riverpod 2.x con AsyncNotifier.
//
// Árbol de providers:
//   dioProvider          → singleton Dio
//   localDataSourceProvider  → MatchLocalDataSource (Hive)
//   remoteDataSourceProvider → FootballRemoteDataSource (Dio)
//   matchRepositoryProvider  → MatchRepositoryImpl
//   matchesNotifierProvider  → AsyncNotifier<List<Match>> (estado principal)
//   filterStateProvider      → FilterState (filtros activos)
//   filteredMatchesProvider  → List<Match> derivada con filtros aplicados

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/match.dart';
import '../../domain/ports/match_repository_port.dart';
import '../../data/datasources/football_remote_datasource.dart';
import '../../data/datasources/match_local_datasource.dart';
import '../../data/repositories/match_repository_impl.dart';

// ═══════════════════════════════════════════════════════════════════════════
// INFRAESTRUCTURA
// ═══════════════════════════════════════════════════════════════════════════

final dioProvider = Provider<Dio>((ref) => createDio());

final localDataSourceProvider = Provider<MatchLocalDataSource>((ref) {
  // Las boxes ya deben estar abiertas en main.dart antes de runApp.
  return MatchLocalDataSource(
    statusBox: Hive.box<int>(HiveConstants.statusBox),
    cacheBox: Hive.box<String>(HiveConstants.cacheBox),
  );
});

final remoteDataSourceProvider = Provider<FootballRemoteDataSource>((ref) {
  return FootballRemoteDataSource(ref.watch(dioProvider));
});

final matchRepositoryProvider = Provider<MatchRepositoryPort>((ref) {
  return MatchRepositoryImpl(
    remote: ref.watch(remoteDataSourceProvider),
    local: ref.watch(localDataSourceProvider),
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// ESTADO DE FILTROS
// ═══════════════════════════════════════════════════════════════════════════

class FilterState {
  final MatchStatus? matchStatus;            // null = todos
  final UserViewingStatus? viewingStatus;    // null = todos

  const FilterState({
    this.matchStatus,
    this.viewingStatus,
  });

  FilterState copyWith({
    Object? matchStatus = _sentinel,
    Object? viewingStatus = _sentinel,
  }) {
    return FilterState(
      matchStatus: matchStatus == _sentinel
          ? this.matchStatus
          : matchStatus as MatchStatus?,
      viewingStatus: viewingStatus == _sentinel
          ? this.viewingStatus
          : viewingStatus as UserViewingStatus?,
    );
  }

  static const _sentinel = Object();
}

final filterStateProvider = StateNotifierProvider<FilterNotifier, FilterState>(
  (ref) => FilterNotifier(),
);

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void setMatchStatus(MatchStatus? status) =>
      state = state.copyWith(matchStatus: status);

  void setViewingStatus(UserViewingStatus? status) =>
      state = state.copyWith(viewingStatus: status);

  void clearAll() => state = const FilterState();
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFIER PRINCIPAL: lista de partidos
// ═══════════════════════════════════════════════════════════════════════════

final matchesNotifierProvider =
    AsyncNotifierProvider<MatchesNotifier, List<Match>>(MatchesNotifier.new);

class MatchesNotifier extends AsyncNotifier<List<Match>> {
  @override
  Future<List<Match>> build() async {
    return ref.watch(matchRepositoryProvider).matches();
  }

  /// Fuerza sincronización con la API.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(matchRepositoryProvider).forceRefresh(),
    );
  }

  /// Actualiza el estado personal de un partido y refleja el cambio
  /// en la lista sin hacer un nuevo fetch a la API.
  Future<void> updateViewingStatus(
    String matchId,
    UserViewingStatus newStatus,
  ) async {
    // Persiste en Hive
    await ref
        .read(matchRepositoryProvider)
        .updateViewingStatus(matchId, newStatus);

    // Actualiza la lista en memoria sin re-fetch
    state = state.whenData(
      (matches) => matches
          .map((m) => m.id == matchId ? m.copyWith(userViewingStatus: newStatus) : m)
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER DERIVADO: partidos filtrados
// ═══════════════════════════════════════════════════════════════════════════

/// Partidos después de aplicar los filtros activos.
/// Se recalcula automáticamente cuando cambia matchesNotifier o filterState.
final filteredMatchesProvider = Provider<AsyncValue<List<Match>>>((ref) {
  final matchesAsync = ref.watch(matchesNotifierProvider);
  final filter = ref.watch(filterStateProvider);

  return matchesAsync.whenData((matches) {
    var result = matches;

    if (filter.matchStatus != null) {
      result = result.where((m) => m.status == filter.matchStatus).toList();
    }
    if (filter.viewingStatus != null) {
      result =
          result.where((m) => m.userViewingStatus == filter.viewingStatus).toList();
    }

    return result;
  });
});

/// Partidos agrupados por fase (para la UI tipo calendario por etapa).
final matchesByStageProvider = Provider<AsyncValue<Map<MatchStage, List<Match>>>>((ref) {
  return ref.watch(filteredMatchesProvider).whenData((matches) {
    final grouped = <MatchStage, List<Match>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.stage, () => []).add(m);
    }
    // Ordenar cada grupo por fecha
    for (final stage in grouped.keys) {
      grouped[stage]!.sort((a, b) => a.utcDate.compareTo(b.utcDate));
    }
    return grouped;
  });
});
