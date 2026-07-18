import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class VisitStatusChart extends StatelessWidget {
  final Map<String, int> statusCounts;

  const VisitStatusChart({super.key, required this.statusCounts});

  @override
  Widget build(BuildContext context) {
    final total = statusCounts.values.fold<int>(0, (sum, val) => sum + val);
    if (total == 0) {
      return Center(
        child: Text('No data', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final planned = (statusCounts['planned'] ?? 0).toDouble();
    final inProgress = (statusCounts['in_progress'] ?? 0).toDouble();
    final completed = (statusCounts['completed'] ?? 0).toDouble();
    final cancelled = (statusCounts['cancelled'] ?? 0).toDouble();

    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          sections: [
            if (planned > 0)
              PieChartSectionData(
                value: planned,
                title: '${(planned / total * 100).toStringAsFixed(1)}%',
                color: const Color(0xFF3e6530),
                radius: 60,
              ),
            if (inProgress > 0)
              PieChartSectionData(
                value: inProgress,
                title: '${(inProgress / total * 100).toStringAsFixed(1)}%',
                color: const Color(0xFFea8e20),
                radius: 60,
              ),
            if (completed > 0)
              PieChartSectionData(
                value: completed,
                title: '${(completed / total * 100).toStringAsFixed(1)}%',
                color: const Color(0xFF528042),
                radius: 60,
              ),
            if (cancelled > 0)
              PieChartSectionData(
                value: cancelled,
                title: '${(cancelled / total * 100).toStringAsFixed(1)}%',
                color: const Color(0xFFd32f2f),
                radius: 60,
              ),
          ],
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }
}
