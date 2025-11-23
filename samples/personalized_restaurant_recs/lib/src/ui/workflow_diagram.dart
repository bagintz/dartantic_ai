import 'package:flutter/material.dart';

/// Custom Flutter workflow diagram (replacing Mermaid)
class WorkflowDiagram extends StatelessWidget {
  const WorkflowDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildNode(context, 'Your Request', Colors.blue.shade100),
          _buildArrow(),
          _buildNode(context, 'Load Restaurant Data', Colors.grey.shade200),
          _buildArrow(),
          _buildNode(context, 'Select Top Candidates', Colors.grey.shade200),
          _buildArrow(),
          _buildNode(context, 'Generate Baseline SOP', Colors.grey.shade200),
          _buildArrow(),

          // Multi-agent section
          _buildNode(context, 'Multi-Agent Analysis', Colors.orange.shade100),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildSmallNode(context, 'Planner')),
              const SizedBox(width: 8),
              Expanded(child: _buildSmallNode(context, 'Data Analyst')),
              const SizedBox(width: 8),
              Expanded(child: _buildSmallNode(context, 'Service')),
              const SizedBox(width: 8),
              Expanded(child: _buildSmallNode(context, 'Sentiment')),
            ],
          ),
          const SizedBox(height: 8),

          _buildArrow(),
          _buildNode(context, 'Synthesizer', Colors.purple.shade100),
          _buildArrow(),
          _buildNode(context, 'Evaluate (6D)', Colors.yellow.shade100),
          _buildArrow(),

          // Decision diamond
          Container(
            width: 120,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              border: Border.all(color: Colors.amber.shade700, width: 2),
            ),
            child: const Center(
              child: Text(
                'Good\nEnough?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  const SizedBox(height: 8),
                  const Text('No', style: TextStyle(fontSize: 10)),
                  const Icon(Icons.arrow_downward, size: 16),
                  const SizedBox(height: 8),
                  _buildNode(context, 'Mutate SOP', Colors.red.shade100, width: 100),
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_upward, size: 16),
                  const Text('Evolve', style: TextStyle(fontSize: 10)),
                ],
              ),
              const SizedBox(width: 40),
              Column(
                children: [
                  const SizedBox(height: 8),
                  const Text('Yes', style: TextStyle(fontSize: 10)),
                  const Icon(Icons.arrow_downward, size: 16),
                  const SizedBox(height: 8),
                  _buildNode(context, 'Rank Restaurants', Colors.grey.shade200, width: 120),
                  const Icon(Icons.arrow_downward, size: 16),
                  _buildNode(context, 'Final Report', Colors.green.shade100, width: 100),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNode(BuildContext context, String label, Color color, {double width = 180}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildSmallNode(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Icon(Icons.arrow_downward, size: 20),
    );
  }
}
