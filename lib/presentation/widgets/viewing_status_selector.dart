// lib/presentation/widgets/viewing_status_selector.dart

import 'package:flutter/material.dart';
import 'package:mundial2026/domain/entities/match.dart';

class ViewingStatusSelector extends StatefulWidget {
  final String matchId;
  final String matchLabel;
  final UserViewingStatus current;
  final bool watchedExtraTime;
  final MatchStage stage;
  final void Function(UserViewingStatus status, bool extraTime) onSelect;

  const ViewingStatusSelector({
    super.key,
    required this.matchId,
    required this.matchLabel,
    required this.current,
    required this.watchedExtraTime,
    required this.stage,
    required this.onSelect,
  });

  @override
  State<ViewingStatusSelector> createState() => _ViewingStatusSelectorState();
}

class _ViewingStatusSelectorState extends State<ViewingStatusSelector> {
  late bool _extraTime;

  @override
  void initState() {
    super.initState();
    _extraTime = widget.watchedExtraTime;
  }

  bool get _isKnockoutStage => widget.stage != MatchStage.groupStage && widget.stage != MatchStage.unknown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.matchLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '¿Cómo viste este partido?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),

          // Opciones de estado
          ...UserViewingStatus.values.map(
            (status) => _StatusOption(
              status: status,
              isSelected: status == widget.current,
              onTap: () => widget.onSelect(status, _extraTime),
            ),
          ),

          // Checkbox de Alargue (solo para eliminatorias)
          if (_isKnockoutStage) ...[
            const SizedBox(height: 8),
            const Divider(),
            CheckboxListTile(
              value: _extraTime,
              onChanged: (val) {
                setState(() => _extraTime = val ?? false);
                // Si ya tiene un estado, lo persistimos al togglear
                widget.onSelect(widget.current, _extraTime);
              },
              title: Row(
                children: [
                  const Text('⏱️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    'Jugó alargue (+30 min)',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: _extraTime ? FontWeight.bold : FontWeight.normal,
                      color: _extraTime ? const Color(0xFFE65100) : null,
                    ),
                  ),
                ],
              ),
              activeColor: const Color(0xFFE65100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final UserViewingStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(status.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                status.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20),
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
