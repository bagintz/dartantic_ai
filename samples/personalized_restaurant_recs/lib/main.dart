import 'package:flutter/material.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

// City with sample zip code for Yelp Academic Dataset
class YelpCity {
  final String name;
  final String zipCode;

  const YelpCity(this.name, this.zipCode);
}

class _HomePageState extends State<HomePage> {
  final _dataProvider = DataProvider(seed: 42);
  final _scrollController = ScrollController();
  final _plannerPromptController = TextEditingController();
  final _synthesizerPromptController = TextEditingController();

  // Common cities in Yelp Academic Dataset
  static const _yelpCities = [
    YelpCity('Philadelphia, PA', '19107'),
    YelpCity('Tampa, FL', '33602'),
    YelpCity('Tucson, AZ', '85701'),
    YelpCity('Nashville, TN', '37201'),
    YelpCity('Indianapolis, IN', '46204'),
    YelpCity('Reno, NV', '89501'),
    YelpCity('Santa Barbara, CA', '93101'),
    YelpCity('Boise, ID', '83702'),
    YelpCity('New Orleans, LA', '70112'),
    YelpCity('St. Louis, MO', '63101'),
  ];

  // User inputs
  YelpCity? _selectedCity;
  UserPersona? _selectedPersona;

  // Configuration
  double _populationSize = 6;
  double _maxGenerations = 3;

  // Data
  List<Restaurant> _restaurants = [];
  Map<String, List<Review>> _reviewsByRestaurant = {};

  // Evolution state
  final List<EvolutionJourneyLog> _evolutionHistory = [];
  bool _isRunning = false;
  String _status = 'Ready to start';
  String _currentPhase = ''; // Added to show high-level phase
  Map<String, RestaurantAnalysisSOP> _currentPopulation = {};

  // Final results
  List<RestaurantRecommendation> _recommendations = [];

  // UI state
  bool _hasStarted = false;
  DataSource? _currentDataSource;

  @override
  void initState() {
    super.initState();
    // Initialize prompt controllers with baseline values
    final baseline = RestaurantAnalysisSOP.baseline();
    _plannerPromptController.text = baseline.plannerPrompt;
    _synthesizerPromptController.text = baseline.synthesizerPrompt;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _plannerPromptController.dispose();
    _synthesizerPromptController.dispose();
    super.dispose();
  }

  void _startOver() {
    setState(() {
      _selectedCity = null;
      _selectedPersona = null;
      _populationSize = 6;
      _maxGenerations = 3;
      _restaurants = [];
      _reviewsByRestaurant = {};
      _evolutionHistory.clear();
      _currentPopulation = {};
      _recommendations = [];
      _status = 'Ready to start';
      _currentPhase = '';
      _hasStarted = false;
      _isRunning = false;
      _currentDataSource = null;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _handleStart() {
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a city')),
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
      _currentPhase = 'LOADING DATA';
      _status = 'Loading restaurant data...';
    });

    try {
      // Load data on first run
      if (_restaurants.isEmpty) {
        await _loadData();
      }

      // Pick a different restaurant for each generation (rotate through the list)
      final restaurantIndex = _evolutionHistory.length % _restaurants.length;
      final restaurant = _restaurants[restaurantIndex];
      final reviews = _reviewsByRestaurant[restaurant.businessId] ?? [];

      final currentGen = _evolutionHistory.length + 1;
      final maxGen = _maxGenerations.toInt();

      setState(() {
        _currentPhase = 'EVOLUTION - Generation $currentGen of $maxGen';
        _status = 'Analyzing ${restaurant.name} with current best SOP...';
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
          populationSize: _populationSize.toInt(),
          eliteCount: (_populationSize / 3).ceil(),
          customBaseline: _createCustomBaseline(), // Use custom prompts from UI
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
        _status = 'Evaluating analysis quality and evolving SOPs...';
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
        populationSize: _populationSize.toInt(),
        eliteCount: (_populationSize / 3).ceil(),
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
            generation: _evolutionHistory.length, // 0-indexed internally
            bestScore: cycleResult.bestResult.overallScore,
            paretoSize: cycleResult.paretoFrontier.length,
            bestResult: cycleResult.bestResult,
            analysisText: result.analysis,
            sop: newBestSop,
            mutationDescription: mutationDesc,
          ),
        );
        _currentPhase = 'EVOLUTION - Generation ${_evolutionHistory.length} of $maxGen';
        _status = 'Generation ${_evolutionHistory.length} complete! (Score: ${cycleResult.bestResult.overallScore.toStringAsFixed(3)})';
        _isRunning = false;
      });

      // Auto-generate recommendations after reaching max generations
      if (_evolutionHistory.length >= _maxGenerations.toInt() && _recommendations.isEmpty) {
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
      _status = 'Checking for Yelp Academic Dataset at /tmp/yelp_dataset/...';
    });

    final dataSource = await _dataProvider.initialize();

    // Store data source in state for persistent UI display
    setState(() {
      _currentDataSource = dataSource;
    });

    String dataSourceLabel;
    String dataSourceDetail;
    if (dataSource == DataSource.yelp) {
      dataSourceLabel = '📊 Real Yelp Data';
      dataSourceDetail = 'Using Yelp Academic Dataset from /tmp/yelp_dataset/';
    } else {
      dataSourceLabel = '🧪 Synthetic Demo Data';
      dataSourceDetail = 'Yelp dataset not found - using generated demo data';
    }

    print('[Main] Data source: $dataSourceLabel - $dataSourceDetail');

    final zipCode = _selectedCity!.zipCode;
    final zipPrefix = zipCode.length >= 3 ? zipCode.substring(0, 3) : zipCode;

    setState(() {
      _status = '$dataSourceLabel - Loading restaurants in ${_selectedCity!.name}...';
    });

    _restaurants = await _dataProvider.loadRestaurantsByZipCode(zipCode);

    if (_restaurants.isEmpty) {
      throw Exception('No restaurants found in zip code area $zipPrefix** (searching $zipCode)');
    }

    print('[Main] Loaded ${_restaurants.length} restaurants, sorting by rating...');

    // Take top 10 by rating
    _restaurants.sort((a, b) => b.stars.compareTo(a.stars));
    _restaurants = _restaurants.take(10).toList();

    print('[Main] Selected top ${_restaurants.length} restaurants by rating');
    _restaurants.forEach((r) => print('  - ${r.name} (${r.stars}★) - ${r.categories.join(", ")}'));

    setState(() {
      _status = '$dataSourceLabel - Loading reviews for ${_restaurants.length} restaurants...';
    });

    _reviewsByRestaurant = await _dataProvider.loadReviews(_restaurants);

    final totalReviews = _reviewsByRestaurant.values.fold(0, (sum, list) => sum + list.length);
    print('[Main] Loaded $totalReviews total reviews');

    // Re-check data source in case fallback occurred during loading
    final actualDataSource = _dataProvider.dataSource;
    final actualDataSourceLabel = actualDataSource == DataSource.yelp ? '📊 Real Yelp Data' : '🧪 Synthetic Demo Data';

    setState(() {
      _currentDataSource = actualDataSource; // Update to actual source used
      _status = '$actualDataSourceLabel - ${_restaurants.length} restaurants, $totalReviews reviews loaded';
    });
  }

  /// Create custom baseline SOP using prompts from UI
  RestaurantAnalysisSOP _createCustomBaseline() {
    return RestaurantAnalysisSOP(
      plannerPrompt: _plannerPromptController.text,
      reviewRetrieverK: 5,
      synthesizerPrompt: _synthesizerPromptController.text,
      synthesizerModel: 'gpt-4o-mini',
      useDataAnalyst: true,
      useServiceAnalyst: false,
      personalizationLevel: 'medium',
      generation: 0,
    );
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

  Future<void> _createFinalRecommendations() async {
    if (_evolutionHistory.isEmpty) {
      return;
    }

    setState(() {
      _currentPhase = 'FINAL SCORING - Testing all restaurants';
      _status = 'Now scoring ALL ${_restaurants.length} restaurants with the evolved SOP...';
    });

    final modelString = const String.fromEnvironment(
      'MODEL',
      defaultValue: 'ollama:deepseek-v3.1:671b-cloud',
    );

    final agent = Agent(modelString);
    final workflow = RestaurantAnalysisWorkflow(agent: agent);
    final evaluator = RestaurantEvaluator(agent: agent);
    final bestSop = _evolutionHistory.last.sop;

    // Analyze and score ALL restaurants with the evolved SOP
    final scoredRestaurants = <({Restaurant restaurant, String analysis, double score})>[];

    for (var i = 0; i < _restaurants.length; i++) {
      final restaurant = _restaurants[i];
      final reviews = _reviewsByRestaurant[restaurant.businessId] ?? [];

      setState(() {
        _status = '${i + 1}/${_restaurants.length}: Analyzing ${restaurant.name}...';
      });

      final result = await workflow.analyze(
        sop: bestSop,
        restaurant: restaurant,
        allReviews: reviews,
        persona: _selectedPersona!,
      );

      // Evaluate the analysis to get a real score
      final evaluation = await evaluator.evaluate(
        sopId: bestSop.id,
        analysis: result.analysis,
        sourceReviews: reviews,
        persona: _selectedPersona!,
      );

      scoredRestaurants.add((
        restaurant: restaurant,
        analysis: result.analysis,
        score: evaluation.overallScore,
      ));
    }

    // Sort by score (highest first) and take top 3
    scoredRestaurants.sort((a, b) => b.score.compareTo(a.score));
    final top3 = scoredRestaurants.take(3).toList();

    final recommendations = top3.asMap().entries.map((entry) {
      final index = entry.key;
      final scored = entry.value;

      return RestaurantRecommendation(
        restaurant: scored.restaurant,
        analysis: scored.analysis,
        score: scored.score,
        rank: index + 1,
      );
    }).toList();

    setState(() {
      _recommendations = recommendations;
      _currentPhase = 'COMPLETE ✓';
      _status = 'Your top ${recommendations.length} personalized recommendations are ready!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Intelligent Restaurant Recommendations'),
        actions: [
          if (_currentDataSource != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Chip(
                avatar: Text(
                  _currentDataSource == DataSource.yelp ? '📊' : '🧪',
                  style: const TextStyle(fontSize: 16),
                ),
                label: Text(
                  _currentDataSource == DataSource.yelp ? 'Real Yelp Data' : 'Synthetic Demo Data',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                backgroundColor: _currentDataSource == DataSource.yelp
                    ? Colors.blue[100]
                    : Colors.orange[100],
                side: BorderSide(
                  color: _currentDataSource == DataSource.yelp ? Colors.blue : Colors.orange,
                  width: 1.5,
                ),
              ),
            ),
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

        DropdownButtonFormField<YelpCity>(
          value: _selectedCity,
          decoration: const InputDecoration(
            labelText: 'City',
            hintText: 'Select a city from the Yelp Academic Dataset',
            helperText: 'These cities have real Yelp review data available',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
          ),
          items: _yelpCities.map((city) {
            return DropdownMenuItem<YelpCity>(
              value: city,
              child: Text(city.name),
            );
          }).toList(),
          onChanged: _hasStarted ? null : (YelpCity? newCity) {
            setState(() {
              _selectedCity = newCity;
            });
          },
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
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'What is an SOP?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'SOP = Standard Operating Procedure. Think of it as a recipe for analyzing restaurants. '
                  'Each SOP defines: how many reviews to read, which AI specialists to use (data analyst, '
                  'service analyst), and how personalized the analysis should be. The system evolves these '
                  '"recipes" to find the best configuration for your preferences.',
                ),
              ],
            ),
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
                  '3. **Genetic Evolution**: The system mutates SOPs '
                  '(number of reviews, which agents to use, personalization level) '
                  'to find better configurations\n\n'
                  '4. **Pareto Optimization**: Finds multiple good SOPs, '
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
                      value: _populationSize,
                      min: 3,
                      max: 12,
                      divisions: 9,
                      label: '${_populationSize.toInt()} SOPs per generation',
                      onChanged: (value) {
                        setState(() {
                          _populationSize = value;
                        });
                      },
                    ),
                    Text(
                      '${_populationSize.toInt()} SOPs per generation',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Number of Generations',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _maxGenerations,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_maxGenerations.toInt()} generations',
                      onChanged: (value) {
                        setState(() {
                          _maxGenerations = value;
                        });
                      },
                    ),
                    Text(
                      '${_maxGenerations.toInt()} generations',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: More generations = better optimization but takes longer',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Baseline Prompts',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Edit these prompts to experiment with how they affect recommendations. '
                      'Changes will be used as the starting point for evolution.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _plannerPromptController,
                      decoration: const InputDecoration(
                        labelText: 'Planner Prompt',
                        helperText: 'Instructions for the analysis planner agent',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 6,
                      enabled: !_hasStarted,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _synthesizerPromptController,
                      decoration: const InputDecoration(
                        labelText: 'Synthesizer Prompt',
                        helperText: 'Instructions for the final recommendation synthesizer',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 8,
                      enabled: !_hasStarted,
                      style: const TextStyle(fontSize: 12),
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
        Text(
          'Evolution Journey',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Phase indicator (only show when actively running or at final completion)
        if (_currentPhase.isNotEmpty && (_isRunning || _currentPhase.contains('COMPLETE')))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _currentPhase.contains('COMPLETE')
                  ? Colors.green.shade100
                  : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPhase.contains('COMPLETE')
                    ? Colors.green
                    : Colors.blue,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentPhase.contains('LOADING')
                      ? Icons.download
                      : _currentPhase.contains('EVOLUTION')
                          ? Icons.science
                          : _currentPhase.contains('FINAL SCORING')
                              ? Icons.assessment
                              : Icons.check_circle,
                  size: 16,
                  color: _currentPhase.contains('COMPLETE')
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentPhase,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _currentPhase.contains('COMPLETE')
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        if (_currentPhase.isNotEmpty && (_isRunning || _currentPhase.contains('COMPLETE'))) const SizedBox(height: 8),

        // Detail status
        Text(
          _status,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _isRunning ? Colors.orange.shade700 : Colors.grey.shade700,
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

        // Process More button at the bottom (only show if not at max generations)
        if (!_isRunning && _evolutionHistory.isNotEmpty && _evolutionHistory.length < _maxGenerations.toInt()) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _runEvolutionCycle,
              icon: const Icon(Icons.add),
              label: const Text('Process More'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScoreChart() {
    final spots = _evolutionHistory
        .map((log) => FlSpot(log.generation.toDouble(), log.bestScore))
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
                // Display as 1-indexed for human readability
                return Text(
                  'Gen ${(value.toInt() + 1)}',
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
    final displayGeneration = log.generation + 1; // Display as 1-indexed
    final maxGen = _maxGenerations.toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: log.generation == 0
              ? Colors.grey
              : (Theme.of(context).colorScheme.primary),
          child: Text('$displayGeneration'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase badge for this generation
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'EVOLUTION - Generation $displayGeneration of $maxGen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Overall Score: ${log.bestScore.toStringAsFixed(3)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${log.paretoSize} optimal SOPs found | '
            'Acc: ${log.bestResult.accuracy.toStringAsFixed(2)}, '
            'Help: ${log.bestResult.helpfulness.toStringAsFixed(2)}, '
            'Pers: ${log.bestResult.personalization.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 2),
          Text(
            'Found ${log.paretoSize} different configurations, each best at different trade-offs',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ],
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
                Text(log.mutationDescription!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
              ],
              Text(
                'Analysis Configuration (SOP):',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSopConfigRow(
                      context,
                      icon: Icons.rate_review,
                      label: 'Review Count',
                      value: '${log.sop.reviewRetrieverK}',
                      description: 'Number of reviews analyzed per restaurant',
                    ),
                    const Divider(height: 16),
                    _buildSopConfigRow(
                      context,
                      icon: Icons.analytics,
                      label: 'Data Analyst',
                      value: log.sop.useDataAnalyst ? 'Enabled' : 'Disabled',
                      description: 'Statistical analysis of review patterns',
                      enabled: log.sop.useDataAnalyst,
                    ),
                    const Divider(height: 16),
                    _buildSopConfigRow(
                      context,
                      icon: Icons.room_service,
                      label: 'Service Analyst',
                      value: log.sop.useServiceAnalyst ? 'Enabled' : 'Disabled',
                      description: 'Deep dive into service quality aspects',
                      enabled: log.sop.useServiceAnalyst,
                    ),
                    const Divider(height: 16),
                    _buildSopConfigRow(
                      context,
                      icon: Icons.person,
                      label: 'Personalization',
                      value: log.sop.personalizationLevel,
                      description: 'How much the analysis tailors to your preferences',
                    ),
                  ],
                ),
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
                child: MarkdownBody(
                  data: log.analysisText,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
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
                    Text('Location: ${_selectedCity?.name ?? "Unknown"}'),
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
                  MarkdownBody(
                    data: rec.analysis,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSopConfigRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String description,
    bool? enabled,
  }) {
    final isEnabled = enabled ?? true;
    final valueColor = enabled == null
        ? Theme.of(context).textTheme.bodyMedium?.color
        : (isEnabled
            ? Colors.green[700]
            : Colors.grey[600]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: valueColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
