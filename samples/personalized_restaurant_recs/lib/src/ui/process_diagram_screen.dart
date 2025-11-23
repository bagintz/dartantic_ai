import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Second screen: Process visualization with Mermaid diagram
class ProcessDiagramScreen extends StatefulWidget {
  const ProcessDiagramScreen({
    required this.onContinue,
    super.key,
  });

  final VoidCallback onContinue;

  @override
  State<ProcessDiagramScreen> createState() => _ProcessDiagramScreenState();
}

class _ProcessDiagramScreenState extends State<ProcessDiagramScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_getMermaidHtml());
  }

  String _getMermaidHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
    mermaid.initialize({ startOnLoad: true, theme: 'default' });
  </script>
  <style>
    body {
      margin: 20px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    .mermaid {
      display: flex;
      justify-content: center;
    }
  </style>
</head>
<body>
  <div class="mermaid">
    graph TB
      A[Your Request] --> B[Load Restaurant Data]
      B --> C[Select Top Candidates]
      C --> D[Generate Baseline SOP]
      D --> E[Multi-Agent Analysis]

      E --> F[Planner Agent]
      E --> G[Data Analyst]
      E --> H[Service Analyst]
      E --> I[Sentiment Analyst]

      F --> J[Synthesizer]
      G --> J
      H --> J
      I --> J

      J --> K[6D Evaluation]
      K --> L{Good Enough?}

      L -->|No| M[Mutate SOP]
      M --> N[Genetic Evolution]
      N --> E

      L -->|Yes| O[Rank Restaurants]
      O --> P[Final Report]

      style A fill:#e1f5ff
      style P fill:#c8e6c9
      style K fill:#fff9c4
      style M fill:#ffccbc
      style N fill:#ffccbc
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works: Self-Improving Analysis',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This system doesn\'t just analyze restaurants - it improves '
                    'its own analysis process while working:\n\n'
                    '1. **Multi-Agent Workflow**: Multiple AI agents collaborate '
                    '(planner, data analyst, service analyst, sentiment analyst)\n\n'
                    '2. **6-Dimensional Evaluation**: Each analysis is scored on '
                    'accuracy, completeness, helpfulness, conciseness, data-grounding, '
                    'and personalization\n\n'
                    '3. **Genetic Evolution**: The system mutates its "SOP genome" '
                    '(number of reviews, which agents to use, personalization level) '
                    'to find better configurations\n\n'
                    '4. **Pareto Optimization**: Finds multiple good solutions, '
                    'not just one, balancing trade-offs across dimensions',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You\'ll see this process unfold in real-time on the next screen!',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Mermaid diagram
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onContinue,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Analysis'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
