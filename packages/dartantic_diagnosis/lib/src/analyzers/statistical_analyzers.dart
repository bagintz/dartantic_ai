import 'dart:math' as math;

/// Base class for statistical analyzers.
abstract class StatisticalAnalyzer {
  const StatisticalAnalyzer();
}

/// Result of a trend analysis.
class TrendResult {
  final double slope;
  final String direction; // 'improving', 'declining', 'stable'
  final double confidence;

  TrendResult(this.slope, this.direction, this.confidence);
  
  @override
  String toString() => 'Trend: $direction (slope: ${slope.toStringAsFixed(4)})';
}

/// Detects improving/declining performance patterns using linear regression.
class TrendAnalyzer extends StatisticalAnalyzer {
  /// Analyzes the trend of a sequence of values.
  /// Returns a [TrendResult].
  TrendResult analyze(List<double> values) {
    if (values.length < 2) {
      return TrendResult(0.0, 'stable', 0.0);
    }

    final n = values.length;
    final x = List.generate(n, (i) => i.toDouble());
    final y = values;

    final sumX = x.reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumX2 = x.map((e) => e * e).reduce((a, b) => a + b);

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    
    // Determine direction and confidence
    // Assuming higher is better? Or lower? 
    // Usually we need to know if the metric is "higher is better" or "lower is better".
    // For now, we just report the direction of the value.
    
    String direction;
    if (slope.abs() < 0.001) {
      direction = 'stable';
    } else {
      direction = slope > 0 ? 'increasing' : 'decreasing';
    }
    
    // Simple confidence based on sample size and slope magnitude
    double confidence = math.min(1.0, (n / 10.0) * (slope.abs() * 10));

    return TrendResult(slope, direction, confidence);
  }
}

/// Result of a correlation analysis.
class CorrelationResult {
  final String parameter;
  final double coefficient;
  final String strength; // 'strong', 'moderate', 'weak', 'none'

  CorrelationResult(this.parameter, this.coefficient, this.strength);
  
  @override
  String toString() => 'Correlation with $parameter: $strength (${coefficient.toStringAsFixed(2)})';
}

/// Finds parameter-performance correlations using Pearson correlation.
class CorrelationAnalyzer extends StatisticalAnalyzer {
  /// Analyzes correlation between a parameter (numeric) and performance metric.
  CorrelationResult analyze(String parameterName, List<double> parameterValues, List<double> performanceValues) {
    if (parameterValues.length != performanceValues.length || parameterValues.length < 2) {
      return CorrelationResult(parameterName, 0.0, 'none');
    }

    final n = parameterValues.length;
    final meanX = parameterValues.reduce((a, b) => a + b) / n;
    final meanY = performanceValues.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double denomX = 0.0;
    double denomY = 0.0;

    for (int i = 0; i < n; i++) {
      final dx = parameterValues[i] - meanX;
      final dy = performanceValues[i] - meanY;
      numerator += dx * dy;
      denomX += dx * dx;
      denomY += dy * dy;
    }

    if (denomX == 0 || denomY == 0) {
      return CorrelationResult(parameterName, 0.0, 'none');
    }

    final r = numerator / math.sqrt(denomX * denomY);
    
    String strength;
    final absR = r.abs();
    if (absR > 0.7) strength = 'strong';
    else if (absR > 0.3) strength = 'moderate';
    else if (absR > 0.1) strength = 'weak';
    else strength = 'none';

    return CorrelationResult(parameterName, r, strength);
  }
}

/// Result of outlier analysis.
class OutlierResult {
  final List<int> outlierIndices;
  final double threshold;

  OutlierResult(this.outlierIndices, this.threshold);
}

/// Identifies anomalous performance cases using Z-score.
class OutlierAnalyzer extends StatisticalAnalyzer {
  /// Returns indices of outliers.
  OutlierResult analyze(List<double> values, {double zScoreThreshold = 2.0}) {
    if (values.length < 3) return OutlierResult([], 0.0);

    final n = values.length;
    final mean = values.reduce((a, b) => a + b) / n;
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / n;
    final stdDev = math.sqrt(variance);

    if (stdDev == 0) return OutlierResult([], 0.0);

    final outliers = <int>[];
    for (int i = 0; i < n; i++) {
      final zScore = (values[i] - mean).abs() / stdDev;
      if (zScore > zScoreThreshold) {
        outliers.add(i);
      }
    }

    return OutlierResult(outliers, stdDev * zScoreThreshold);
  }
}

/// Result of variance analysis.
class VarianceResult {
  final double variance;
  final double stdDev;
  final String stability; // 'stable', 'volatile'

  VarianceResult(this.variance, this.stdDev, this.stability);
  
  @override
  String toString() => 'Stability: $stability (stdDev: ${stdDev.toStringAsFixed(2)})';
}

/// Analyzes performance stability.
class VarianceAnalyzer extends StatisticalAnalyzer {
  VarianceResult analyze(List<double> values) {
    if (values.isEmpty) return VarianceResult(0.0, 0.0, 'stable');

    final n = values.length;
    final mean = values.reduce((a, b) => a + b) / n;
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / n;
    final stdDev = math.sqrt(variance);
    
    // Heuristic for stability - depends on the scale of values, but let's use coefficient of variation if mean != 0
    String stability = 'stable';
    if (mean != 0) {
      final cv = stdDev / mean.abs();
      if (cv > 0.2) stability = 'volatile'; // > 20% variation
    } else if (stdDev > 0.1) {
      stability = 'volatile'; // Absolute threshold if mean is 0
    }

    return VarianceResult(variance, stdDev, stability);
  }
}
