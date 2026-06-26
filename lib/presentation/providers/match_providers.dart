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

import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:mundial2026/core/constants/api_constants.dart';
import 'package:mundial2026/domain/entities/match.dart';
import 'package:mundial2026/domain/ports/match_repository_port.dart';
import 'package:mundial2026/data/datasources/football_remote_datasource.dart';
import 'package:mundial2026/data/datasources/match_local_datasource.dart';
import 'package:mundial2026/data/repositories/match_repository_impl.dart';
import 'package:mundial2026/domain/entities/standing.dart';
import 'package:mundial2026/domain/usecases/get_matches_usecase.dart';
import 'package:mundial2026/domain/usecases/update_viewing_status_usecase.dart';
import 'package:mundial2026/domain/usecases/force_refresh_matches_usecase.dart';
import 'package:mundial2026/domain/usecases/get_all_viewing_statuses_usecase.dart';
import 'package:mundial2026/domain/usecases/get_standings_usecase.dart';

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

// Use‑case providers
final getMatchesUseCaseProvider = Provider<GetMatchesUseCase>((ref) =>
    GetMatchesUseCase(ref.read(matchRepositoryProvider)));

final updateViewingStatusUseCaseProvider = Provider<UpdateViewingStatusUseCase>((ref) =>
    UpdateViewingStatusUseCase(ref.read(matchRepositoryProvider)));

final forceRefreshMatchesUseCaseProvider = Provider<ForceRefreshMatchesUseCase>((ref) =>
    ForceRefreshMatchesUseCase(ref.read(matchRepositoryProvider)));

final getAllViewingStatusesUseCaseProvider = Provider<GetAllViewingStatusesUseCase>((ref) =>
    GetAllViewingStatusesUseCase(ref.read(matchRepositoryProvider)));

final getStandingsUseCaseProvider = Provider<GetStandingsUseCase>((ref) =>
    GetStandingsUseCase(ref.read(matchRepositoryProvider)));


// ═══════════════════════════════════════════════════════════════════════════
// CHART MODE (false = barras lineales, true = gráfico de torta)
// ═══════════════════════════════════════════════════════════════════════════

/// Alterna entre vista de barras y vista de torta en los paneles de stats.
final chartModeProvider = StateProvider<bool>((ref) => false);

// ═══════════════════════════════════════════════════════════════════════════
// STANDINGS
// ═══════════════════════════════════════════════════════════════════════════

/// Carga las tablas de posiciones de todos los grupos.
final standingsProvider = FutureProvider<List<GroupStanding>>((ref) {
  return ref.read(getStandingsUseCaseProvider).call();
});

/// Terceros de cada grupo, ordenados por puntos > DG > GF.
final bestThirdPlaceProvider = FutureProvider<List<GroupStanding>>((ref) {
  return ref.read(getStandingsUseCaseProvider).getBestThirdPlace();
});

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD & CALENDAR STATE
// ═══════════════════════════════════════════════════════════════════════════

final dashboardExpandedProvider = StateProvider<bool>((ref) => true);

final selectedDateProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
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
    return ref.read(getMatchesUseCaseProvider).call();
  }

  /// Fuerza sincronización con la API.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(forceRefreshMatchesUseCaseProvider).call(),
    );
  }

  /// Actualiza el estado personal de un partido y refleja el cambio
  /// en la lista sin hacer un nuevo fetch a la API.
  Future<void> updateViewingStatus(
    String matchId,
    UserViewingStatus newStatus,
  ) async {
    // Persiste en Hive via use case
    await ref.read(updateViewingStatusUseCaseProvider).call(matchId, newStatus);

    // Actualiza la lista en memoria sin re-fetch
    state = state.whenData(
      (matches) => matches
          .map((m) => m.id == matchId ? m.copyWith(userViewingStatus: newStatus) : m)
          .toList(),
    );
  }

  /// Rellena aleatoriamente los estados de los partidos finalizados
  Future<void> randomFillFinishedMatches() async {
    final matches = state.valueOrNull;
    if (matches == null) return;

    final random = Random();
    final updatedMatches = [...matches];
    bool hasChanges = false;

    for (int i = 0; i < updatedMatches.length; i++) {
      final m = updatedMatches[i];
      if (m.status == MatchStatus.finished) {
        final rand = random.nextDouble();
        UserViewingStatus newStatus;
        if (rand < 0.1) {
          newStatus = UserViewingStatus.notWatched;
        } else if (rand < 0.3) {
          newStatus = UserViewingStatus.halfTime;
        } else if (rand < 0.7) {
          newStatus = UserViewingStatus.watched;
        } else {
          newStatus = UserViewingStatus.summary;
        }

        if (m.userViewingStatus != newStatus) {
          await ref
                .read(updateViewingStatusUseCaseProvider)
                .call(m.id, newStatus);
          updatedMatches[i] = m.copyWith(userViewingStatus: newStatus);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      state = AsyncData(updatedMatches);
    }
  }

  /// Exporta el estado local a JSON
  Future<String> exportStatusesJson() async {
    final statuses = await ref.read(getAllViewingStatusesUseCaseProvider).call();
    final map = statuses.map((k, v) => MapEntry(k, v.index));
    return jsonEncode(map);
  }

  /// Importa el estado desde JSON
  Future<void> importStatusesJson(String jsonStr) async {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final matchId = entry.key;
        final statusIndex = entry.value as int;
        if (statusIndex >= 0 && statusIndex < UserViewingStatus.values.length) {
          final status = UserViewingStatus.values[statusIndex];
          await updateViewingStatus(matchId, status);
        }
      }
    } catch (e) {
      throw Exception('Formato de JSON inválido');
    }
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

// ═══════════════════════════════════════════════════════════════════════════
// CALENDAR & GROUPING PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

DateTime _normalizeDate(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

final availableDatesProvider = Provider<AsyncValue<List<DateTime>>>((ref) {
  return ref.watch(matchesNotifierProvider).whenData((matches) {
    final dates = matches.map((m) => _normalizeDate(m.utcDate)).toSet().toList();
    dates.sort();
    return dates;
  });
});

final matchesByDayProvider = Provider<AsyncValue<Map<DateTime, List<Match>>>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  return ref.watch(filteredMatchesProvider).whenData((matches) {
    final grouped = <DateTime, List<Match>>{};
    
    var filtered = matches;
    if (selectedDate != null) {
      filtered = matches.where((m) => _normalizeDate(m.utcDate) == selectedDate).toList();
    }

    for (final m in filtered) {
      final day = _normalizeDate(m.utcDate);
      grouped.putIfAbsent(day, () => []).add(m);
    }
    
    // Sort keys (days)
    final sortedGrouped = <DateTime, List<Match>>{};
    final sortedDays = grouped.keys.toList()..sort();
    
    for (final day in sortedDays) {
      grouped[day]!.sort((a, b) => a.utcDate.compareTo(b.utcDate));
      sortedGrouped[day] = grouped[day]!;
    }
    return sortedGrouped;
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// STATS PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final worldCupProgressProvider = Provider<double>((ref) {
  final matches = ref.watch(matchesNotifierProvider).valueOrNull ?? [];
  if (matches.isEmpty) return 0.0;
  final finished = matches.where((m) => m.status == MatchStatus.finished).length;
  return finished / matches.length;
});

final viewingStatsProvider = Provider<Map<UserViewingStatus, double>>((ref) {
  final matches = ref.watch(matchesNotifierProvider).valueOrNull ?? [];
  final stats = {
    UserViewingStatus.notWatched: 0.0,
    UserViewingStatus.halfTime: 0.0,
    UserViewingStatus.watched: 0.0,
    UserViewingStatus.summary: 0.0,
  };
  if (matches.isEmpty) return stats;

  for (final m in matches) {
    stats[m.userViewingStatus] = (stats[m.userViewingStatus] ?? 0) + 1;
  }
  for (final key in stats.keys.toList()) {
    stats[key] = stats[key]! / matches.length;
  }
  return stats;
});

// ═══════════════════════════════════════════════════════════════════════════
// MIS ESTADÍSTICAS (solo partidos finalizados con estado cargado por el usuario)
// ═══════════════════════════════════════════════════════════════════════════

/// Estadísticas personales del usuario: cuántos partidos finalizados marcó
/// con cada estado. Solo cuenta partidos con status == finished.
final myStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final matches = ref.watch(matchesNotifierProvider).valueOrNull ?? [];
  final finished = matches.where((m) => m.status == MatchStatus.finished).toList();
  
  final counts = {
    UserViewingStatus.notWatched: 0,
    UserViewingStatus.halfTime: 0,
    UserViewingStatus.watched: 0,
    UserViewingStatus.summary: 0,
  };
  
  for (final m in finished) {
    counts[m.userViewingStatus] = (counts[m.userViewingStatus] ?? 0) + 1;
  }
  
  final totalFinished = finished.length;
  final totalTracked = totalFinished - (counts[UserViewingStatus.notWatched] ?? 0);
  
  final percentages = <UserViewingStatus, double>{};
  for (final entry in counts.entries) {
    percentages[entry.key] = totalFinished > 0 ? entry.value / totalFinished : 0.0;
  }
  
  return {
    'totalFinished': totalFinished,
    'totalTracked': totalTracked,
    'counts': counts,
    'percentages': percentages,
  };
});

final myStatsExpandedProvider = StateProvider<bool>((ref) => false);
