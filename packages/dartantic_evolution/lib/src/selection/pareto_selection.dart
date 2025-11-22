import '../gene_pool/generation.dart';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/selection_strategy.dart';

class ParetoSelection<T extends EvolvableConfiguration<T>> implements SelectionStrategy<T> {
  @override
  String get name => 'Pareto';

  @override
  List<T> select(Generation<T> generation, int count) {
    var population = generation.population;
    var scores = generation.multiObjectiveScores;
    
    if (population.isEmpty) return [];
    if (scores.isEmpty) {
      // Fallback to single objective if no multi-objective scores
      // Or just random if no scores at all
      return population.take(count).map((e) => e.clone()).toList();
    }

    // Calculate dominance rank for each individual
    // This is O(N^2) which is fine for small populations
    var ranks = <String, int>{};
    for (var p in population) {
      ranks[p.id] = 0;
    }

    for (var i = 0; i < population.length; i++) {
      for (var j = 0; j < population.length; j++) {
        if (i == j) continue;
        if (_dominates(population[j], population[i], scores)) {
          ranks[population[i].id] = (ranks[population[i].id] ?? 0) + 1;
        }
      }
    }

    // Sort by rank (lower is better)
    var sorted = List<T>.from(population);
    sorted.sort((a, b) {
      var rankA = ranks[a.id] ?? 0;
      var rankB = ranks[b.id] ?? 0;
      return rankA.compareTo(rankB);
    });

    // Select top count
    // If we need more than available, we cycle or just take what we have
    var selected = <T>[];
    for (var i = 0; i < count; i++) {
      selected.add(sorted[i % sorted.length].clone());
    }
    
    return selected;
  }

  bool _dominates(T a, T b, Map<String, Map<String, double>> scores) {
    var scoresA = scores[a.id];
    var scoresB = scores[b.id];
    
    if (scoresA == null || scoresB == null) return false;

    bool atLeastOneBetter = false;
    for (var metric in scoresA.keys) {
      var valA = scoresA[metric] ?? double.negativeInfinity;
      var valB = scoresB[metric] ?? double.negativeInfinity;
      
      if (valA < valB) return false; // A is worse in one metric
      if (valA > valB) atLeastOneBetter = true;
    }
    
    return atLeastOneBetter;
  }
}
