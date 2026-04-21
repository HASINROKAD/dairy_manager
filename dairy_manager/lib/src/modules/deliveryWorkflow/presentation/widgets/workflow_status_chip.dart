import 'package:flutter/material.dart';

class WorkflowStatusChip extends StatelessWidget {
  const WorkflowStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;

    switch (normalized) {
      case 'open':
      case 'pending':
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        break;
      case 'resolved':
      case 'approved':
        background = Colors.green.withValues(alpha: 0.15);
        foreground = Colors.green.shade800;
        break;
      case 'rejected':
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        break;
      default:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.isEmpty ? 'unknown' : normalized,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
