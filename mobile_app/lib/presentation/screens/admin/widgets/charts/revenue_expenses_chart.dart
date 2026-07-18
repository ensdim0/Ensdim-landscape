import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class RevenueExpensesChart extends StatelessWidget {
  final num revenue;
  final num expenses;
  final num net;

  const RevenueExpensesChart({
    super.key,
    required this.revenue,
    required this.expenses,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = [
      revenue,
      expenses,
    ].fold<num>(0, (max, val) => val > max ? val : max);
    if (maxY == 0) {
      return Center(
        child: Text('No data', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final normalizedRevenue = revenue / maxY * 100;
    final normalizedExpenses = expenses / maxY * 100;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
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
                  const titles = ['Revenue', 'Expenses'];
                  if (value.toInt() < titles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        titles[value.toInt()],
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
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: normalizedRevenue.toDouble(),
                  color: const Color(0xFF528042),
                  width: 40,
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: normalizedExpenses.toDouble(),
                  color: const Color(0xFFd32f2f),
                  width: 40,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
