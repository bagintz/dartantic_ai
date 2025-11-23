import 'package:flutter/material.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
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
import 'src/ui/stakeholder_intro_screen.dart';
import 'src/ui/process_diagram_screen.dart';
import 'src/ui/evolution_journey_screen.dart';
import 'src/ui/stakeholder_report_screen.dart';

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

class _HomePageState extends State<HomePage> {
  int _currentStep = 0;
  final _dataProvider = DataProvider(seed: 42);

  // User inputs
  String? _zipCode;
  UserPersona? _selectedPersona;

  // Data
  List<Restaurant> _restaurants = [];
  Map<String, List<Review>> _reviewsByRestaurant = {};

  // Evolution state
  final List<EvolutionJourneyLog> _evolutionHistory = [];
  bool _isRunning = false;
  String _status = 'Ready';
  Map<String, RestaurantAnalysisSOP> _currentPopulation = {};

  // Final results
  List<RestaurantRecommendation> _recommendations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Intelligent Restaurant Recommendations'),
      ),
      body: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return StakeholderIntroScreen(
          personas: _dataProvider.getSamplePersonas(),
          onContinue: _handleIntroComplete,
        );
      case 1:
        return ProcessDiagramScreen(
          onContinue: _handleDiagramComplete,
        );
      case 2:
        return EvolutionJourneyScreen(
          evolutionHistory: _evolutionHistory,
          isRunning: _isRunning,
          status: _status,
          onProcessMore: _runEvolutionCycle,
          onFinish: _handleEvolutionComplete,
        );
      case 3:
        return StakeholderReportScreen(
          recommendations: _recommendations,
          persona: _selectedPersona!,
          zipCode: _zipCode!,
          generationsProcessed: _evolutionHistory.length,
          onRestart: _handleRestart,
        );
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  void _handleIntroComplete(String zipCode, UserPersona persona) {
    setState(() {
      _zipCode = zipCode;
      _selectedPersona = persona;
      _currentStep = 1;
    });
  }

  void _handleDiagramComplete() {
    setState(() {
      _currentStep = 2;
    });
    // Start first evolution cycle automatically
    _runEvolutionCycle();
  }

  void _handleEvolutionComplete() {
    // Create final recommendations from evolution results
    _createFinalRecommendations();
    setState(() {
      _currentStep = 3;
    });
  }

  void _handleRestart() {
    setState(() {
      _currentStep = 0;
      _zipCode = null;
      _selectedPersona = null;
      _restaurants = [];
      _reviewsByRestaurant = {};
      _evolutionHistory.clear();
      _currentPopulation = {};
      _recommendations = [];
      _status = 'Ready';
    });
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
        final workflow = RestaurantAnalysisWorkflow(agent: agent);
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
      final newBestSop = cycleResult.population[cycleResult.bestOverall]!;

      // Generate mutation description
      String? mutationDesc;
      if (_evolutionHistory.isNotEmpty) {
        final previousSop = _evolutionHistory.last.sop;
        mutationDesc = _describeMutation(previousSop, newBestSop);
      }

      setState(() {
        _evolutionHistory.add(
          EvolutionJourneyLog(
            generation: _evolutionHistory.length,
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

    setState(() {
      _status = 'Data source: ${dataSource.name}. Loading restaurants...';
    });

    _restaurants = await _dataProvider.loadRestaurantsByZipCode(_zipCode!);

    if (_restaurants.isEmpty) {
      throw Exception('No restaurants found in zip code $_zipCode');
    }

    // Take top 10 by rating
    _restaurants.sort((a, b) => b.stars.compareTo(a.stars));
    _restaurants = _restaurants.take(10).toList();

    setState(() {
      _status = 'Loading reviews for ${_restaurants.length} restaurants...';
    });

    _reviewsByRestaurant = await _dataProvider.loadReviews(_restaurants);

    setState(() {
      _status = 'Data loaded. Starting evolution...';
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
    // Use the best evolved SOP to analyze all restaurants
    // For now, create mock recommendations from top 3 restaurants
    _recommendations = _restaurants.take(3).toList().asMap().entries.map((entry) {
      final index = entry.key;
      final restaurant = entry.value;

      // Get the last analysis if available, or create generic one
      final analysis = _evolutionHistory.isNotEmpty
          ? _evolutionHistory.last.analysisText
          : 'Great restaurant with excellent reviews.';

      return RestaurantRecommendation(
        restaurant: restaurant,
        analysis: analysis,
        score: 0.9 - (index * 0.1), // Simple mock scoring
        rank: index + 1,
      );
    }).toList();
  }
}
