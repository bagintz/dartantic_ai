import 'package:flutter/material.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:fl_chart/fl_chart.dart';
import 'src/config/restaurant_analysis_sop.dart';
import 'src/data/data_provider.dart';
import 'src/evaluation/evaluation_result.dart';
import 'src/evaluation/restaurant_evaluator.dart';
import 'src/evolution/evolution_engine.dart';
import 'src/evolution/mutation_strategy.dart';
import 'src/evolution/selection_strategy.dart';
import 'src/models/restaurant.dart';
import 'src/models/review.dart';
import 'src/models/user_persona.dart';
import 'src/workflows/restaurant_analysis_workflow.dart';
import 'src/ui/workflow_diagram.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Self-Improving Restaurant Recommendations',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

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

class RestaurantRecommendation {
  RestaurantRecommendation({
    required this.restaurant,
    required this.analysis,
    required this.score,
    required this.rank,
  });

  final Restaurant restaurant;
  final String analysis;
  final double score;
  final int rank;
}

class _HomePageState extends State<HomePage> {
  final _dataProvider = DataProvider(seed: 42);
  final _zipCodeController = TextEditingController();
  final _scrollController = ScrollController();

  // User inputs
  UserPersona? _selectedPersona;

  // Data
  List<Restaurant> _restaurants = [];
  Map<String, List<Review>> _reviewsByRestaurant = {};

  // Evolution state
  final List<EvolutionJourneyLog> _evolutionHistory = [];
  bool _isRunning = false;
  String _status = 'Ready to start';
  Map<String, RestaurantAnalysisSOP> _currentPopulation = {};

  // Final results
  List<RestaurantRecommendation> _recommendations = [];

  // UI state
  bool _hasStarted = false;

  @override
  void dispose() {
    _zipCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startOver() {
    setState(() {
      _zipCodeController.clear();
      _selectedPersona = null;
      _restaurants = [];
      _reviewsByRestaurant = {};
      _evolutionHistory.clear();
      _currentPopulation = {};
      _recommendations = [];
      _status = 'Ready to start';
      _hasStarted = false;
      _isRunning = false;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _handleStart() {
    final zipCode = _zipCodeController.text.trim();
    if (zipCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a zip code')),
      );
      return;
    }

    if (_selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a diner type')),
      );
      return;
    }

    setState(() {
      _hasStarted = true;
    });

    // Start first evolution cycle automatically
    _runEvolutionCycle();
  }

  Future<void> _runEvolutionCycle() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _status = 'Loading data...';
    });

    try {
      // Load data on first run
      if (_restaurants.isEmpty) {
        await _loadData();
      }

      // Pick a random restaurant for this cycle
      final restaurant = _restaurants.first;
      final reviews = _reviewsByRestaurant[restaurant.businessId] ?? [];

      setState(() {
        _status = 'Running analysis (Generation ${_evolutionHistory.length})...';
      });

      // Initialize or use current population
      if (_currentPopulation.isEmpty) {
        final modelString = const String.fromEnvironment(
          'MODEL',
          defaultValue: 'ollama:deepseek-v3.1:671b-cloud',
        );

        final agent = Agent(modelString);
        final evaluator = RestaurantEvaluator(agent: agent);

        final mutationStrategy = CompositeMutation(
          strategies: [
            ParameterTweakMutation(),
            StructuralMutation(),
            PromptEnhancementMutation(),
          ],
        );

        final engine = EvolutionEngine(
          evaluator: evaluator,
          mutationStrategy: mutationStrategy,
          selectionStrategy: ParetoSelection(),
          populationSize: 6,
          eliteCount: 2,
        );

        _currentPopulation = engine.initializePopulation();
      }

      // Run workflow with best SOP from current population
      final modelString = const String.fromEnvironment(
        'MODEL',
        defaultValue: 'ollama:deepseek-v3.1:671b-cloud',
      );

      final agent = Agent(modelString);
      final workflow = RestaurantAnalysisWorkflow(agent: agent);
      final evaluator = RestaurantEvaluator(agent: agent);

      final bestSop = _currentPopulation.values.first;

      final result = await workflow.analyze(
        sop: bestSop,
        restaurant: restaurant,
        allReviews: reviews,
        persona: _selectedPersona!,
      );

      // Evolve
      setState(() {
        _status = 'Evaluating and evolving...';
      });

      final mutationStrategy = CompositeMutation(
        strategies: [
          ParameterTweakMutation(),
          StructuralMutation(),
          PromptEnhancementMutation(),
        ],
      );

      final engine = EvolutionEngine(
        evaluator: evaluator,
        mutationStrategy: mutationStrategy,
        selectionStrategy: ParetoSelection(),
        populationSize: 6,
        eliteCount: 2,
      );

      final cycleResult = await engine.evolve(
        currentPopulation: _currentPopulation,
        analysisText: result.analysis,
        sourceReviews: reviews,
        persona: _selectedPersona!,
      );

      // Update population for next generation
      _currentPopulation = cycleResult.population;

      // Get the best SOP from the cycle result
      final newBestSop = cycleResult.population[cycleResult.bestOverall];
      if (newBestSop == null) {
        throw Exception('Best SOP not found in population for key: ${cycleResult.bestOverall}');
      }

      // Generate mutation description
      String? mutationDesc;
      if (_evolutionHistory.isNotEmpty) {
        final previousSop = _evolutionHistory.last.sop;
        mutationDesc = _describeMutation(previousSop, newBestSop);
      }

      setState(() {
        _evolutionHistory.add(
          EvolutionJourneyLog(
            generation: _evolutionHistory.length + 1, // Start at 1, not 0
            bestScore: cycleResult.bestResult.overallScore,
            paretoSize: cycleResult.paretoFrontier.length,
            bestResult: cycleResult.bestResult,
            analysisText: result.analysis,
            sop: newBestSop,
            mutationDescription: mutationDesc,
          ),
        );
        _status = 'Generation ${_evolutionHistory.length} complete!';
        _isRunning = false;
      });

      // Auto-generate recommendations after 3 generations
      if (_evolutionHistory.length >= 3 && _recommendations.isEmpty) {
        _createFinalRecommendations();
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _status = 'Loading restaurant data...';
    });

    final dataSource = await _dataProvider.initialize();

    final dataSourceLabel = dataSource == DataSource.yelp
        ? '📊 Real Yelp Data'
        : '🧪 Synthetic Demo Data';

    final zipCode = _zipCodeController.text.trim();
    final zipPrefix = zipCode.length >= 3 ? zipCode.substring(0, 3) : zipCode;

    setState(() {
      _status = '$dataSourceLabel - Loading restaurants in area $zipPrefix**...';
    });

    _restaurants = await _dataProvider.loadRestaurantsByZipCode(zipCode);

    if (_restaurants.isEmpty) {
      throw Exception('No restaurants found in zip code area $zipPrefix** (searching $zipCode)');
    }

    // Take top 10 by rating
    _restaurants.sort((a, b) => b.stars.compareTo(a.stars));
    _restaurants = _restaurants.take(10).toList();

    setState(() {
      _status = '$dataSourceLabel - Loading reviews for ${_restaurants.length} restaurants...';
    });

    _reviewsByRestaurant = await _dataProvider.loadReviews(_restaurants);

    setState(() {
      _status = '$dataSourceLabel - Data loaded. Starting evolution...';
    });
  }

  String _describeMutation(RestaurantAnalysisSOP baseline, RestaurantAnalysisSOP mutated) {
    final changes = <String>[];

    if (baseline.reviewRetrieverK != mutated.reviewRetrieverK) {
      changes.add('Review count: ${baseline.reviewRetrieverK} → ${mutated.reviewRetrieverK}');
    }

    if (baseline.useDataAnalyst != mutated.useDataAnalyst) {
      changes.add('Data analyst: ${baseline.useDataAnalyst ? "enabled" : "disabled"} → ${mutated.useDataAnalyst ? "enabled" : "disabled"}');
    }

    if (baseline.useServiceAnalyst != mutated.useServiceAnalyst) {
      changes.add('Service analyst: ${baseline.useServiceAnalyst ? "enabled" : "disabled"} → ${mutated.useServiceAnalyst ? "enabled" : "disabled"}');
    }

    if (baseline.personalizationLevel != mutated.personalizationLevel) {
      changes.add('Personalization: ${baseline.personalizationLevel} → ${mutated.personalizationLevel}');
    }

    if (baseline.plannerPrompt != mutated.plannerPrompt) {
      changes.add('Planner prompt modified');
    }

    if (baseline.synthesizerPrompt != mutated.synthesizerPrompt) {
      changes.add('Synthesizer prompt modified');
    }

    if (changes.isEmpty) {
      return 'No changes (elite carried forward)';
    }

    return changes.join('\n');
  }

  void _createFinalRecommendations() {
    // Use top 3 restaurants with the evolved analysis
    _recommendations = _restaurants.take(3).toList().asMap().entries.map((entry) {
      final index = entry.key;
      final restaurant = entry.value;

      // Get the last analysis if available
      final analysis = _evolutionHistory.isNotEmpty
          ? _evolutionHistory.last.analysisText
          : 'Great restaurant with excellent reviews.';

      return RestaurantRecommendation(
        restaurant: restaurant,
        analysis: analysis,
        score: 0.9 - (index * 0.1),
        rank: index + 1,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Intelligent Restaurant Recommendations'),
        actions: [
          if (_hasStarted)
            TextButton.icon(
              onPressed: _startOver,
              icon: const Icon(Icons.refresh),
              label: const Text('Start Over'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroSection(),
            const Divider(height: 48),
            _buildProcessSection(),
            if (_hasStarted) ...[
              const Divider(height: 48),
              _buildEvolutionSection(),
            ],
            if (_recommendations.isNotEmpty) ...[
              const Divider(height: 48),
              _buildRecommendationsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🍽️ Welcome to Intelligent Restaurant Recommendations',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why This Tool?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Finding the perfect restaurant is hard. Traditional recommendation '
                  'systems give you generic ratings that don\'t match YOUR preferences.\n\n'
                  'This tool uses advanced AI to:\n'
                  '• Analyze thousands of reviews through multiple lenses\n'
                  '• Understand YOUR unique dining preferences\n'
                  '• Self-improve its analysis process in real-time\n'
                  '• Provide personalized, evidence-based recommendations',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text(
          'Tell Us About You',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _zipCodeController,
          decoration: const InputDecoration(
            labelText: 'Zip Code',
            hintText: 'Enter your zip code (e.g., 43204 searches Columbus area)',
            helperText: 'Searches all restaurants in the same 3-digit area',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          keyboardType: TextInputType.number,
          enabled: !_hasStarted,
        ),
        const SizedBox(height: 24),

        Text(
          'What Type of Diner Are You?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        ..._dataProvider.getSamplePersonas().map((persona) {
          final isSelected = _selectedPersona?.name == persona.name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: _hasStarted
                  ? null
                  : () {
                      setState(() {
                        _selectedPersona = persona;
                      });
                    },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          persona.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 40.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(persona.description),
                          const SizedBox(height: 4),
                          Text(
                            'Priorities: ${persona.priorities.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProcessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works: Self-Improving Analysis',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

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
                const SizedBox(height: 16),
                const WorkflowDiagram(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Advanced configuration (optional)
        if (!_hasStarted)
          ExpansionTile(
            title: const Text('⚙️ Advanced Configuration (Optional)'),
            subtitle: const Text('Customize evolution parameters'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Population Size',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: 6,
                      min: 3,
                      max: 12,
                      divisions: 9,
                      label: '6 SOPs per generation',
                      onChanged: null, // TODO: Wire up configuration
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Number of Generations',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: 3,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '3 generations',
                      onChanged: null, // TODO: Wire up configuration
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: More generations = better optimization but takes longer',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // Start button at the end of the journey explanation
        if (!_hasStarted)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Find My Perfect Restaurant'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEvolutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Evolution Journey',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (!_isRunning && _evolutionHistory.isNotEmpty)
              FilledButton.icon(
                onPressed: _runEvolutionCycle,
                icon: const Icon(Icons.add),
                label: const Text('Process More'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _status,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _isRunning ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),

        if (_evolutionHistory.isNotEmpty) ...[
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

        Card(
          child: _evolutionHistory.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('Evolution will begin automatically...'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _evolutionHistory.length,
                  itemBuilder: (context, index) {
                    final log = _evolutionHistory[index];
                    return _buildEvolutionTile(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScoreChart() {
    final spots = _evolutionHistory
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
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  Widget _buildEvolutionTile(EvolutionJourneyLog log) {
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: log.generation == 1
            ? Colors.grey
            : (Theme.of(context).colorScheme.primary),
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
              if (log.mutationDescription != null) ...[
                Text(
                  'Mutations Applied:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(log.mutationDescription, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
              ],
              Text(
                'SOP Configuration:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
              Text(
                'Detailed Evaluation Scores:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
              Text(
                'Generated Analysis:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(log.analysisText, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Personalized Recommendations',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on ${_evolutionHistory.length} generations of self-improvement',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diner Profile: ${_selectedPersona?.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_selectedPersona?.description ?? ''),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on),
                    const SizedBox(width: 12),
                    Text(() {
                      final zipCode = _zipCodeController.text;
                      final zipPrefix = zipCode.length >= 3 ? zipCode.substring(0, 3) : zipCode;
                      return 'Location: Zip Code Area $zipPrefix** (${zipCode})';
                    }()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.restaurant),
                    const SizedBox(width: 12),
                    Text('Found ${_recommendations.length} top matches'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Top Recommendations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        ..._recommendations.map(_buildRecommendationCard),
      ],
    );
  }

  Widget _buildRecommendationCard(RestaurantRecommendation rec) {
    final medalColors = [Colors.amber, Colors.grey[400]!, Colors.brown[300]!];
    final medalIcons = ['🥇', '🥈', '🥉'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: medalColors[rec.rank - 1],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(medalIcons[rec.rank - 1], style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.restaurant.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text('${rec.restaurant.stars.toStringAsFixed(1)} stars', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(width: 16),
                          Text('${rec.restaurant.reviewCount} reviews', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Match: ${(rec.score * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: rec.restaurant.categories.take(3).map((category) {
                return Chip(label: Text(category), visualDensity: VisualDensity.compact);
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text('${rec.restaurant.city}, ${rec.restaurant.state}'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'AI-Powered Analysis',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(rec.analysis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
