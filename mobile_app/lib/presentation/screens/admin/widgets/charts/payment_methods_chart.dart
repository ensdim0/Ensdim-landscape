import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PaymentMethodsChart extends StatelessWidget {
  final List<Map<String, dynamic>> payments;

  const PaymentMethodsChart({super.key, required this.payments});

  @override
  Widget build(BuildContext context) {
    // Count by payment method
    final methodCounts = <String, num>{};
    for (final p in payments) {
      final method = (p['payment_method']?.toString() ?? 'cash').toLowerCase();
      methodCounts[method] =
          (methodCounts[method] ?? 0) + ((p['amount'] as num?) ?? 0);
    }

    if (methodCounts.isEmpty) {
      return Center(
        child: Text('No data', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final sorted = methodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxAmount = sorted.fold<num>(
      0,
      (max, e) => e.value > max ? e.value : max,
    );

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxAmount / 1).toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < sorted.length) {
                    final method = sorted[value.toInt()].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        method.substring(0, 1).toUpperCase() +
                            method.substring(1),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: sorted
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.value.toDouble(),
                      color: _getColorForMethod(e.value.key),
                      width: 40,
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Color _getColorForMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color(0xFF528042);
      case 'transfer':
      case 'bank_transfer':
        return const Color(0xFF3e6530);
      case 'check':
        return const Color(0xFFea8e20);
      default:
        return const Color(0xFF22301a);
    }
  }
}
