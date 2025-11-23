import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../evaluation/evaluation_result.dart';
import '../config/restaurant_analysis_sop.dart';

/// Evolution log entry for the journey
class EvolutionJourneyLog {
  EvolutionJourneyLog({
    required this.generation,
    required this.bestScore,
    required this.paretoSize,
    required this.bestResult,
    required this.analysisText,
    required this.sop,
    this.mutationDescription,
  });

  final int generation;
  final double bestScore;
  final int paretoSize;
  final EvaluationResult bestResult;
  final String analysisText;
  final RestaurantAnalysisSOP sop;
  final String? mutationDescription;
}

/// Third screen: Evolution journey with real-time progress
class EvolutionJourneyScreen extends StatelessWidget {
  const EvolutionJourneyScreen({
    required this.evolutionHistory,
    required this.isRunning,
    required this.status,
    required this.onProcessMore,
    required this.onFinish,
    super.key,
  });

  final List<EvolutionJourneyLog> evolutionHistory;
  final bool isRunning;
  final String status;
  final VoidCallback onProcessMore;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Evolution Journey',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isRunning ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 16),

          // Progress chart
          if (evolutionHistory.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score Evolution',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _buildScoreChart(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Evolution timeline
          Expanded(
            child: evolutionHistory.isEmpty
                ? const Center(
                    child: Text('Starting evolution...'),
                  )
                : Card(
                    child: ListView.builder(
                      itemCount: evolutionHistory.length,
                      itemBuilder: (context, index) {
                        final log = evolutionHistory[index];
                        return _buildEvolutionTile(context, log);
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isRunning ? null : onProcessMore,
                  icon: Icon(isRunning ? Icons.hourglass_empty : Icons.add),
                  label: Text(isRunning ? 'Processing...' : 'Process More'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRunning || evolutionHistory.isEmpty
                      ? null
                      : onFinish,
                  icon: const Icon(Icons.check),
                  label: const Text('View Results'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChart() {
    final spots = evolutionHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.bestScore))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  'Gen ${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionTile(BuildContext context, EvolutionJourneyLog log) {
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: log.generation == 0
            ? Colors.grey
            : Theme.of(context).colorScheme.primary,
        child: Text('${log.generation}'),
      ),
      title: Text(
        'Generation ${log.generation} - Overall: ${log.bestScore.toStringAsFixed(3)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Pareto Frontier: ${log.paretoSize} SOPs | '
        'Acc: ${log.bestResult.accuracy.toStringAsFixed(2)}, '
        'Help: ${log.bestResult.helpfulness.toStringAsFixed(2)}, '
        'Pers: ${log.bestResult.personalization.toStringAsFixed(2)}',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mutation description
              if (log.mutationDescription != null) ...[
                Text(
                  'Mutations Applied:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  log.mutationDescription!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],

              // SOP Configuration
              Text(
                'SOP Configuration:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review Count: ${log.sop.reviewRetrieverK}\n'
                'Data Analyst: ${log.sop.useDataAnalyst ? "Enabled" : "Disabled"}\n'
                'Service Analyst: ${log.sop.useServiceAnalyst ? "Enabled" : "Disabled"}\n'
                'Personalization Level: ${log.sop.personalizationLevel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Evaluation Scores
              Text(
                'Detailed Evaluation Scores:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Accuracy: ${log.bestResult.accuracy.toStringAsFixed(3)}\n'
                'Completeness: ${log.bestResult.completeness.toStringAsFixed(3)}\n'
                'Helpfulness: ${log.bestResult.helpfulness.toStringAsFixed(3)}\n'
                'Conciseness: ${log.bestResult.conciseness.toStringAsFixed(3)}\n'
                'Data-Grounded: ${log.bestResult.dataGrounded.toStringAsFixed(3)}\n'
                'Personalization: ${log.bestResult.personalization.toStringAsFixed(3)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Generated Analysis
              Text(
                'Generated Analysis:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.analysisText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
