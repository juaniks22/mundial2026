// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mundial2026/domain/entities/match.dart';
import 'package:mundial2026/presentation/providers/match_providers.dart';
import '../widgets/match_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesByDayProvider);
    final filter = ref.watch(filterStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'fifa logo wc26.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Mundial 2026', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar',
            onPressed: () => ref.read(matchesNotifierProvider.notifier).refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _showExportDialog(context, ref);
              } else if (value == 'import') {
                _showImportDialog(context, ref);
              } else if (value == 'autofill') {
                _confirmAutoFill(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'autofill', child: Row(
                children: [
                  Icon(Icons.auto_fix_high, size: 20),
                  SizedBox(width: 8),
                  Text('Auto-rellenar'),
                ],
              )),
              PopupMenuItem(value: 'export', child: Text('Exportar datos (.json)')),
              PopupMenuItem(value: 'import', child: Text('Importar datos (.json)')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: _FilterBar(currentFilter: filter),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(matchesNotifierProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _DashboardPanel(),
            const _MyStatsPanel(),
            const _DateSelector(),
            matchesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => _ErrorState(
                message: err.toString(),
                onRetry: () => ref.read(matchesNotifierProvider.notifier).refresh(),
              ),
              data: (groupedMatches) {
                if (groupedMatches.isEmpty) {
                  return const _EmptyState();
                }
                return _MatchList(groupedMatches: groupedMatches);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Dashboard Colapsable
// ─────────────────────────────────────────────────────────────────────────

class _DashboardPanel extends ConsumerWidget {
  const _DashboardPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(dashboardExpandedProvider);
    final progress = ref.watch(worldCupProgressProvider);
    final stats = ref.watch(viewingStatsProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            onTap: () => ref.read(dashboardExpandedProvider.notifier).state = !isExpanded,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart, color: Color(0xFF009EE3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dashboard de Estadísticas',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mundial jugado: ${(progress * 100).toStringAsFixed(1)}%'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                    color: const Color(0xFF009EE3),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tus visualizaciones:'),
                  const SizedBox(height: 8),
                  _StatBar(
                    label: 'No visto',
                    value: stats[UserViewingStatus.notWatched] ?? 0.0,
                    color: Colors.red,
                  ),
                  _StatBar(
                    label: 'Medio tiempo',
                    value: stats[UserViewingStatus.halfTime] ?? 0.0,
                    color: const Color(0xFF51EB2F),
                  ),
                  _StatBar(
                    label: 'Visto',
                    value: stats[UserViewingStatus.watched] ?? 0.0,
                    color: Colors.green,
                  ),
                  _StatBar(
                    label: 'Resumen',
                    value: stats[UserViewingStatus.summary] ?? 0.0,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Mis Estadísticas (partidos finalizados cargados por el usuario)
// ─────────────────────────────────────────────────────────────────────────

class _MyStatsPanel extends ConsumerWidget {
  const _MyStatsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(myStatsExpandedProvider);
    final myStats = ref.watch(myStatsProvider);
    final theme = Theme.of(context);

    final totalFinished = myStats['totalFinished'] as int;
    final totalTracked = myStats['totalTracked'] as int;
    final counts = myStats['counts'] as Map<UserViewingStatus, int>;
    final percentages = myStats['percentages'] as Map<UserViewingStatus, double>;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => ref.read(myStatsExpandedProvider.notifier).state = !isExpanded,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF009EE3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mis Estadísticas',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Partidos finalizados: ',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '$totalFinished',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Seguimiento realizado: ',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '$totalTracked / $totalFinished',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF009EE3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Desglose de partidos finalizados:'),
                  const SizedBox(height: 8),
                  _MyStatRow(
                    emoji: '🟢',
                    label: 'Visto completo',
                    count: counts[UserViewingStatus.watched] ?? 0,
                    percentage: percentages[UserViewingStatus.watched] ?? 0.0,
                    color: Colors.green,
                  ),
                  _MyStatRow(
                    emoji: '🟡',
                    label: 'Medio tiempo',
                    count: counts[UserViewingStatus.halfTime] ?? 0,
                    percentage: percentages[UserViewingStatus.halfTime] ?? 0.0,
                    color: const Color(0xFF51EB2F),
                  ),
                  _MyStatRow(
                    emoji: '🔵',
                    label: 'Vi el resumen',
                    count: counts[UserViewingStatus.summary] ?? 0,
                    percentage: percentages[UserViewingStatus.summary] ?? 0.0,
                    color: Colors.blue,
                  ),
                  _MyStatRow(
                    emoji: '🔴',
                    label: 'No visto',
                    count: counts[UserViewingStatus.notWatched] ?? 0,
                    percentage: percentages[UserViewingStatus.notWatched] ?? 0.0,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _MyStatRow extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _MyStatRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$count (${(percentage * 100).toStringAsFixed(0)}%)',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
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

        const SizedBox(height: 6),

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
// Selector de Fecha (Dual: Scroll horizontal + DatePicker)
// ─────────────────────────────────────────────────────────────────────────

class _DateSelector extends ConsumerWidget {
  const _DateSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableDatesAsync = ref.watch(availableDatesProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return availableDatesAsync.when(
      data: (dates) {
        if (dates.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filtrar por fecha:', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Color(0xFF009EE3)),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? dates.first,
                        firstDate: dates.first,
                        lastDate: dates.last,
                      );
                      if (date != null) {
                        ref.read(selectedDateProvider.notifier).state = date;
                      }
                    },
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _DateChip(
                    label: 'Todos',
                    isSelected: selectedDate == null,
                    onTap: () => ref.read(selectedDateProvider.notifier).state = null,
                  ),
                  for (final date in dates)
                    _DateChip(
                      label: DateFormat('d MMM').format(date),
                      isSelected: selectedDate == date,
                      onTap: () => ref.read(selectedDateProvider.notifier).state = date,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Lista agrupada por día
// ─────────────────────────────────────────────────────────────────────────

class _MatchList extends StatelessWidget {
  final Map<DateTime, List<Match>> groupedMatches;

  const _MatchList({required this.groupedMatches});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedMatches.entries.map((entry) {
        final date = entry.key;
        final matches = entry.value;
        final simpleDate = '${_weekDay(date.weekday)} ${date.day} de ${_month(date.month)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                simpleDate,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            ...matches.map((m) => MatchCard(match: m)),
          ],
        );
      }).toList(),
    );
  }

  String _weekDay(int w) {
    switch (w) {
      case 1: return 'Lunes';
      case 2: return 'Martes';
      case 3: return 'Miércoles';
      case 4: return 'Jueves';
      case 5: return 'Viernes';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return '';
    }
  }

  String _month(int m) {
    switch (m) {
      case 1: return 'Enero';
      case 2: return 'Febrero';
      case 3: return 'Marzo';
      case 4: return 'Abril';
      case 5: return 'Mayo';
      case 6: return 'Junio';
      case 7: return 'Julio';
      case 8: return 'Agosto';
      case 9: return 'Septiembre';
      case 10: return 'Octubre';
      case 11: return 'Noviembre';
      case 12: return 'Diciembre';
      default: return '';
    }
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
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⚽', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No hay partidos con esos filtros'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Diálogos y utilidades
// ─────────────────────────────────────────────────────────────────────────

Future<void> _confirmAutoFill(BuildContext context, WidgetRef ref) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Auto-rellenar?'),
      content: const Text(
          'Esto asignará estados aleatorios a los partidos finalizados y sobrescribirá tus estados actuales para esos partidos. ¿Estás seguro?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sí, rellenar'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    ref.read(matchesNotifierProvider.notifier).randomFillFinishedMatches();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partidos rellenados aleatoriamente')),
      );
    }
  }
}

void _showExportDialog(BuildContext context, WidgetRef ref) {
  final jsonStr = ref.read(matchesNotifierProvider.notifier).exportStatusesJson();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Exportar Datos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Copiá el siguiente texto y guardalo en un lugar seguro para poder restaurarlo luego.'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            height: 100,
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(jsonStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copiar JSON'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonStr));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado al portapapeles')));
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

void _showImportDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Importar Datos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pegá el JSON que exportaste anteriormente:'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '{"match_id": 1, ...}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Importar'),
          onPressed: () async {
            try {
              await ref.read(matchesNotifierProvider.notifier).importStatusesJson(controller.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos importados correctamente')));
                Navigator.pop(context);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: JSON inválido'), backgroundColor: Colors.red));
              }
            }
          },
        ),
      ],
    ),
  );
}
