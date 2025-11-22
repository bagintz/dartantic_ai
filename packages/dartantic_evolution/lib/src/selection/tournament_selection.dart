import 'dart:math';
import '../gene_pool/generation.dart';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/selection_strategy.dart';

class TournamentSelection<T extends EvolvableConfiguration<T>> implements SelectionStrategy<T> {
  final int tournamentSize;
  final Random _random = Random();

  TournamentSelection({this.tournamentSize = 3});

  @override
  String get name => 'Tournament';

  @override
  List<T> select(Generation<T> generation, int count) {
    var population = generation.population;
    var fitnessScores = generation.fitnessScores;
    var selected = <T>[];
    
    if (population.isEmpty) return selected;

    for (var i = 0; i < count; i++) {
      var tournament = <T>[];
      for (var j = 0; j < tournamentSize; j++) {
        tournament.add(population[_random.nextInt(population.length)]);
      }
      // Select best from tournament
      var best = tournament.reduce((a, b) {
        var scoreA = fitnessScores[a.id] ?? double.negativeInfinity;
        var scoreB = fitnessScores[b.id] ?? double.negativeInfinity;
        return scoreA > scoreB ? a : b;
      });
      selected.add(best.clone());
    }
    return selected;
  }
}
