import 'package:flutter/material.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'src/data/synthetic_data.dart';
import 'src/evaluation/evaluation_result.dart';
import 'src/evaluation/restaurant_evaluator.dart';
import 'src/evolution/evolution_engine.dart';
import 'src/evolution/mutation_strategy.dart';
import 'src/evolution/selection_strategy.dart';
import 'src/models/restaurant.dart';
import 'src/models/review.dart';
import 'src/models/user_persona.dart';
import 'src/workflows/restaurant_analysis_workflow.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

class _HomePageState extends State<HomePage> {
  final _dataGenerator = SyntheticDataGenerator(seed: 42);
  late final List<Restaurant> _restaurants;
  late final Map<String, List<Review>> _reviewsByRestaurant;

  bool _isRunning = false;
  int _currentGeneration = 0;
  String _status = 'Ready to evolve';
  final List<EvolutionLog> _evolutionHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final dataset = _dataGenerator.generateDataset(
      restaurantCount: 5,
      reviewsPerRestaurant: 15,
    );

    _restaurants = dataset['restaurants'] as List<Restaurant>;
    final allReviews = dataset['reviews'] as List<Review>;

    _reviewsByRestaurant = {};
    for (final review in allReviews) {
      _reviewsByRestaurant.putIfAbsent(review.businessId, () => []);
      _reviewsByRestaurant[review.businessId]!.add(review);
    }
  }

  Future<void> _runEvolutionCycle() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _status = 'Initializing evolution...';
    });

    try {
      // Initialize agent (would need API key in real usage)
      final agent = Agent('openai:gpt-4o-mini');

      // Select test restaurant and persona
      final restaurant = _restaurants.first;
      final persona = UserPersona.foodie;
      final reviews = _reviewsByRestaurant[restaurant.businessId]!;

      setState(() => _status = 'Running baseline analysis...');

      // Create workflow and evaluator
      final workflow = RestaurantAnalysisWorkflow(agent: agent);
      final evaluator = RestaurantEvaluator(agent: agent);

      // Create evolution engine
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

      // Initialize population
      var population = engine.initializePopulation();

      setState(() {
        _status = 'Running generation ${_currentGeneration + 1}...';
      });

      // Run workflow with baseline SOP
      final baselineSOP = population.values.first;
      final result = await workflow.analyze(
        sop: baselineSOP,
        restaurant: restaurant,
        allReviews: reviews,
        persona: persona,
      );

      // Run one evolution cycle
      final cycleResult = await engine.evolve(
        currentPopulation: population,
        analysisText: result.analysis,
        sourceReviews: reviews,
        persona: persona,
      );

      setState(() {
        _currentGeneration++;
        _evolutionHistory.add(
          EvolutionLog(
            generation: _currentGeneration,
            bestScore: cycleResult.bestResult.overallScore,
            paretoSize: cycleResult.paretoFrontier.length,
            bestResult: cycleResult.bestResult,
          ),
        );
        _status = 'Generation $_currentGeneration complete!';
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Self-Improving Restaurant RAG'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolution Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Generation: $_currentGeneration'),
                    Text('Status: $_status'),
                    Text('Restaurants: ${_restaurants.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_evolutionHistory.isNotEmpty) ...[
              Text(
                'Evolution History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: _evolutionHistory.length,
                    itemBuilder: (context, index) {
                      final log = _evolutionHistory[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${log.generation}'),
                        ),
                        title: Text(
                          'Overall: ${log.bestScore.toStringAsFixed(3)}',
                        ),
                        subtitle: Text(
                          'Pareto Frontier: ${log.paretoSize} SOPs\n'
                          'Acc: ${log.bestResult.accuracy.toStringAsFixed(2)}, '
                          'Help: ${log.bestResult.helpfulness.toStringAsFixed(2)}, '
                          'Pers: ${log.bestResult.personalization.toStringAsFixed(2)}',
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Click "Run Evolution Cycle" to start\n\n'
                    'This will demonstrate self-improvement:\n'
                    '• Generate baseline SOP\n'
                    '• Run multi-agent analysis\n'
                    '• Evaluate across 5 dimensions\n'
                    '• Evolve better configurations\n'
                    '• Track Pareto frontier',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRunning ? null : _runEvolutionCycle,
        label: Text(_isRunning ? 'Running...' : 'Run Evolution Cycle'),
        icon: Icon(_isRunning ? Icons.hourglass_empty : Icons.play_arrow),
      ),
    );
  }
}

class EvolutionLog {
  EvolutionLog({
    required this.generation,
    required this.bestScore,
    required this.paretoSize,
    required this.bestResult,
  });

  final int generation;
  final double bestScore;
  final int paretoSize;
  final EvaluationResult bestResult;
}
