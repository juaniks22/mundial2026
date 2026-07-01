// lib/presentation/widgets/match_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:mundial2026/domain/entities/match.dart';
import '../providers/match_providers.dart';
import 'viewing_status_selector.dart';

class MatchCard extends ConsumerWidget {
  final Match match;

  const MatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStatusSelector(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildHeader(theme),
              const SizedBox(height: 10),
              _buildTeamsRow(theme),
              const SizedBox(height: 10),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    final stageColor = _stageColor(match.stage);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Grupo o fase con color por etapa
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: stageColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: stageColor,
              width: 1,
            ),
          ),
          child: Text(
            match.group != null
                ? 'Grupo ${match.group!.replaceAll('GROUP_', '')}'
                : match.stage.label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Estado oficial del partido
        _MatchStatusChip(status: match.status),
      ],
    );
  }

  Widget _buildTeamsRow(ThemeData theme) {
    final hasScore = match.score.hasScore;

    return Row(
      children: [
        // Home team
        Expanded(
          child: _TeamBlock(
            team: match.homeTeam,
            alignment: CrossAxisAlignment.start,
          ),
        ),

        // Score o tiempo del partido
        SizedBox(
          width: 80,
          child: Center(
            child: hasScore
                ? Column(
                    children: [
                      Text(
                        match.score.scoreline!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (match.score.homeHalfTimeGoals != null)
                        Text(
                          '(${match.score.homeHalfTimeGoals}-${match.score.awayHalfTimeGoals})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      Text(
                        match.status == MatchStatus.live ? '🔴 LIVE' : 'VS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: match.status == MatchStatus.live
                              ? Colors.red
                              : null,
                        ),
                      ),
                      Text(
                        _formatTime(match.utcDate),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
          ),
        ),

        // Away team
        Expanded(
          child: _TeamBlock(
            team: match.awayTeam,
            alignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Venue
        if (match.venue != null)
          Flexible(
            child: Text(
              '📍 ${match.venue}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Estado personal del usuario — toca para cambiar
        _ViewingStatusBadge(
          status: match.userViewingStatus,
          onTap: () {},
        ),
      ],
    );
  }

  void _showStatusSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ViewingStatusSelector(
        matchId: match.id,
        matchLabel: '${match.homeTeam.tla} vs ${match.awayTeam.tla}',
        current: match.userViewingStatus,
        watchedExtraTime: match.watchedExtraTime,
        stage: match.stage,
        onSelect: (status, extraTime) {
          ref
              .read(matchesNotifierProvider.notifier)
              .updateViewingStatus(match.id, status);
          ref
              .read(matchesNotifierProvider.notifier)
              .updateExtraTimeStatus(match.id, extraTime);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _formatTime(DateTime utc) {
    // Convertimos a hora local Argentina (UTC-3)
    final local = utc.toLocal();
    return DateFormat('HH:mm').format(local);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────

class _TeamBlock extends StatelessWidget {
  final Team team;
  final CrossAxisAlignment alignment;

  const _TeamBlock({required this.team, required this.alignment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        // Crest del equipo (SVG desde football-data.org)
        if (team.crestUrl != null)
          team.crestUrl!.endsWith('.svg')
              ? SvgPicture.network(
                  team.crestUrl!,
                  width: 36,
                  height: 36,
                  placeholderBuilder: (_) => const Icon(Icons.shield, size: 36),
                )
              : CachedNetworkImage(
                  imageUrl: team.crestUrl!,
                  width: 36,
                  height: 36,
                  errorWidget: (_, __, ___) => const Icon(Icons.shield, size: 36),
                )
        else
          const Icon(Icons.shield_outlined, size: 36),

        const SizedBox(height: 4),
        Text(
          team.shortName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: alignment == CrossAxisAlignment.start
              ? TextAlign.left
              : TextAlign.right,
        ),
        Text(
          team.tla,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _MatchStatusChip extends StatelessWidget {
  final MatchStatus status;

  const _MatchStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MatchStatus.live      => ('EN VIVO', Colors.red),
      MatchStatus.finished  => ('FIN', Colors.grey),
      MatchStatus.postponed => ('POSTERGADO', Colors.orange),
      MatchStatus.cancelled => ('CANCELADO', Colors.red.shade900),
      MatchStatus.scheduled => ('', Colors.transparent),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _ViewingStatusBadge extends StatelessWidget {
  final UserViewingStatus status;
  final VoidCallback onTap;

  const _ViewingStatusBadge({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor(status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(UserViewingStatus s) => switch (s) {
    UserViewingStatus.notWatched => Colors.red,
    UserViewingStatus.halfTime   => const Color(0xFF51EB2F),
    UserViewingStatus.watched    => Colors.green,
    UserViewingStatus.summary    => Colors.blue,
  };
}

/// Retorna un color profesional por cada fase del Mundial.
Color _stageColor(MatchStage stage) => switch (stage) {
  MatchStage.groupStage   => const Color(0xFFFFD700), // Dorado
  MatchStage.roundOf32    => const Color(0xFF81D4FA), // Azul claro
  MatchStage.roundOf16    => const Color(0xFFCE93D8), // Violeta
  MatchStage.quarterFinal => const Color(0xFFEF9A9A), // Rojo suave
  MatchStage.semiFinal    => const Color(0xFFE0E0E0), // Blanco plateado
  MatchStage.thirdPlace   => const Color(0xFFE0E0E0), // Blanco plateado
  MatchStage.final_       => const Color(0xFFE0E0E0), // Blanco plateado
  MatchStage.unknown      => const Color(0xFF757575), // Gris
};
