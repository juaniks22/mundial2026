// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/match.dart';
import '../providers/match_providers.dart';
import '../widgets/match_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(filteredMatchesProvider);
    final filter = ref.watch(filterStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Mundial 2026', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar',
            onPressed: () =>
                ref.read(matchesNotifierProvider.notifier).refresh(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: _FilterBar(currentFilter: filter),
        ),
      ),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () =>
              ref.read(matchesNotifierProvider.notifier).refresh(),
        ),
        data: (matches) {
          if (matches.isEmpty) {
            return const _EmptyState();
          }
          return _MatchList(matches: matches);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Barra de filtros
// ─────────────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final FilterState currentFilter;

  const _FilterBar({required this.currentFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(filterStateProvider.notifier);

    return Column(
      children: [
        // Fila 1: Estado oficial del partido
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: currentFilter.matchStatus == null,
                onTap: () => notifier.setMatchStatus(null),
              ),
              _FilterChip(
                label: '🔴 En vivo',
                selected: currentFilter.matchStatus == MatchStatus.live,
                onTap: () => notifier.setMatchStatus(MatchStatus.live),
              ),
              _FilterChip(
                label: 'Programados',
                selected: currentFilter.matchStatus == MatchStatus.scheduled,
                onTap: () => notifier.setMatchStatus(MatchStatus.scheduled),
              ),
              _FilterChip(
                label: 'Finalizados',
                selected: currentFilter.matchStatus == MatchStatus.finished,
                onTap: () => notifier.setMatchStatus(MatchStatus.finished),
              ),
            ],
          ),
        ),

        // Fila 2: Estado de visualización personal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: currentFilter.viewingStatus == null,
                onTap: () => notifier.setViewingStatus(null),
              ),
              for (final s in UserViewingStatus.values)
                _FilterChip(
                  label: '${s.emoji} ${s.label}',
                  selected: currentFilter.viewingStatus == s,
                  onTap: () => notifier.setViewingStatus(s),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Lista agrupada por fase
// ─────────────────────────────────────────────────────────────────────────

class _MatchList extends ConsumerWidget {
  final List<Match> matches;

  const _MatchList({required this.matches});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Agrupar por fase
    final grouped = <MatchStage, List<Match>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.stage, () => []).add(m);
    }

    // Ordenar fases en orden del torneo
    final orderedStages = MatchStage.values.where(grouped.containsKey).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(matchesNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: orderedStages.length,
        itemBuilder: (context, index) {
          final stage = orderedStages[index];
          final stageMatches = grouped[stage]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la fase
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stage.label,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    Text(
                      '${stageMatches.length} partidos',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                    ),
                  ],
                ),
              ),

              // Partidos de la fase
              ...stageMatches.map((m) => MatchCard(match: m)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Estados de error y vacío
// ─────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⚽', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('No hay partidos con esos filtros'),
        ],
      ),
    );
  }
}
