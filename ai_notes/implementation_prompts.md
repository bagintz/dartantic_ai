# Implementation Prompts for Self-Improvement Packages

## Overview

These prompts are designed to be fed to Gemini 3 in VSCode for implementing each complementary package. Each prompt is self-contained and includes the complete specification and implementation guidance.

---

## 🔧 Prompt 1: dartantic_evaluation Package

```
I need to implement a comprehensive multi-dimensional evaluation framework for AI workflows. This package should provide standardized interfaces for assessing outputs across multiple competing objectives with Pareto frontier analysis.

Please implement a Dart package called `dartantic_evaluation` with the following specification:

### Core Requirements:

1. **EvaluationScore class**: Represents a single dimension score (0.0-1.0) with reasoning and metadata
2. **Evaluator interface**: Abstract interface for dimension-specific assessment  
3. **EvaluationResult class**: Container for multi-dimensional scores with computed overall score
4. **MultiDimensionalEvaluator class**: Coordinates multiple evaluators and finds Pareto optimal solutions

### Built-in Evaluator Types:
- **LLMJudgeEvaluator**: Uses dartantic_ai Agent for AI-powered evaluation with JSON schema
- **MetricBasedEvaluator**: Extracts and normalizes numeric metrics from output
- **HumanFeedbackEvaluator**: Async callback pattern for human input

### Key Features:
- Pareto frontier analysis using dominance comparison
- JSON schema validation for LLM outputs
- Extensible evaluator pattern for custom dimensions
- Comprehensive scoring with reasoning explanations

### Dependencies:
```yaml
dependencies:
  dartantic_ai: ^VERSION
  dartantic_interface: ^VERSION  
  json_schema: ^VERSION
  logging: ^VERSION
```

### Implementation Details:
- All evaluators should implement the abstract `Evaluator` interface
- LLMJudgeEvaluator should use dartantic_ai Agent with structured output
- MultiDimensionalEvaluator should implement proper Pareto dominance logic
- Include comprehensive documentation and usage examples
- Add proper error handling and validation

Please provide the complete package implementation with all files, including:
- lib/dartantic_evaluation.dart (main export)
- lib/src/evaluators/ (evaluator implementations)
- lib/src/results/ (result classes)
- example/basic_usage.dart (usage demonstration)
- pubspec.yaml (package configuration)

Focus on clean architecture, proper error handling, and comprehensive documentation.
```

---

## 🔧 Prompt 2: dartantic_evolution Package

```
I need to implement a genetic algorithm and configuration optimization framework for evolving AI workflow configurations. This package should provide evolutionary patterns for systematic improvement.

Please implement a Dart package called `dartantic_evolution` with the following specification:

### Core Requirements:

1. **EvolvableConfiguration interface**: Abstract interface for configurations that can mutate and crossover
2. **MutationStrategy interface**: Pluggable mutation algorithms  
3. **ConfigurationGenePool class**: Tracks configuration lineage and performance evolution
4. **SelectionStrategy interface**: Different selection algorithms for breeding

### Built-in Mutation Strategies:
- **ParameterTweakMutation**: Adjusts numeric parameters within ranges
- **ParameterSwapMutation**: Swaps discrete parameter values from predefined options
- **StructuralMutation**: Modifies configuration structure (add/remove components)

### Built-in Selection Strategies:
- **TournamentSelection**: Tournament-based parent selection
- **ParetoSelection**: Selection based on Pareto optimality

### Key Features:
- Generation tracking with timestamps and metadata
- Configuration crossover and mutation operations
- Performance-based fitness calculation
- Persistent gene pool state management
- Configuration lineage and evolution history

### Dependencies:
```yaml
dependencies:
  dartantic_evaluation: ^VERSION
  logging: ^VERSION
  uuid: ^VERSION
```

### Implementation Details:
- EvolvableConfiguration should be generic with type safety
- ConfigurationGenePool should track all generations and evaluations
- Mutation strategies should be composable and configurable
- Include proper random number generation for genetic operations
- Support both in-memory and persistent gene pools
- Add comprehensive mutation probability controls

Please provide the complete package implementation with all files, including:
- lib/dartantic_evolution.dart (main export)
- lib/src/interfaces/ (core interfaces)
- lib/src/mutations/ (mutation strategy implementations)
- lib/src/selection/ (selection strategy implementations)  
- lib/src/gene_pool/ (gene pool management)
- example/genetic_optimization.dart (comprehensive example)
- pubspec.yaml (package configuration)

Focus on robust genetic algorithms, type safety, and flexible configuration patterns.
```

---

## 🔧 Prompt 3: dartantic_diagnosis Package  

```
I need to implement a performance analysis and weakness identification framework for AI systems. This package should provide automated root cause analysis and targeted improvement recommendations.

Please implement a Dart package called `dartantic_diagnosis` with the following specification:

### Core Requirements:

1. **PerformanceDiagnosis class**: Contains weakness analysis, root causes, and recommendations
2. **ImprovementRecommendation class**: Structured guidance for specific parameter changes
3. **PerformanceDiagnostician interface**: Abstract interface for performance analysis
4. **DiagnosisPromptTemplate class**: Customizable templates for LLM analysis

### Built-in Diagnostician Types:
- **LLMDiagnostician**: Uses dartantic_ai Agent for AI-powered root cause analysis
- **StatisticalDiagnostician**: Uses statistical methods for trend and correlation analysis
- **HybridDiagnostician**: Combines both LLM and statistical approaches

### Statistical Analyzers:
- **TrendAnalyzer**: Detects improving/declining performance patterns
- **CorrelationAnalyzer**: Finds parameter-performance correlations  
- **OutlierAnalyzer**: Identifies anomalous performance cases
- **VarianceAnalyzer**: Analyzes performance stability

### Key Features:
- Structured recommendation output with confidence scores
- Customizable prompt templates for domain-specific analysis
- Statistical trend analysis with linear regression
- Multi-dimensional weakness identification
- Actionable improvement suggestions with difficulty estimates

### Dependencies:
```yaml
dependencies:
  dartantic_ai: ^VERSION
  dartantic_evaluation: ^VERSION
  dartantic_evolution: ^VERSION
  json_schema: ^VERSION
  logging: ^VERSION
```

### Implementation Details:
- LLMDiagnostician should use structured JSON output with schema validation
- Statistical analyzers should implement proper mathematical algorithms
- Include comprehensive prompt engineering for effective AI diagnosis
- Support both automated and human-readable explanations
- Add confidence scoring for all recommendations
- Implement proper error handling for analysis failures

Please provide the complete package implementation with all files, including:
- lib/dartantic_diagnosis.dart (main export)
- lib/src/diagnosticians/ (diagnostician implementations)
- lib/src/analyzers/ (statistical analyzer implementations)
- lib/src/templates/ (prompt template system)
- lib/src/models/ (data models for diagnosis results)
- example/performance_analysis.dart (comprehensive example)
- pubspec.yaml (package configuration)

Focus on accurate analysis algorithms, effective prompt engineering, and actionable recommendations.
```

---

## 🔧 Prompt 4: dartantic_optimization Package

```
I need to implement a self-improvement orchestration layer that coordinates evaluation, diagnosis, and evolution into autonomous optimization loops. This should be the top-level coordination package.

Please implement a Dart package called `dartantic_optimization` with the following specification:

### Core Requirements:

1. **SelfImprovementEngine interface**: Coordinates one complete evolution cycle
2. **DefaultSelfImprovementEngine class**: Full implementation of the optimization loop
3. **EvolutionParameters class**: Configuration for optimization behavior
4. **OptimizationStatus enum**: Tracking optimization state
5. **EvolutionCycleResult class**: Results from one optimization cycle

### Orchestration Components:
- **AutonomousOptimizationLoop**: Continuous improvement with streaming progress
- **BatchOptimizationRunner**: Controlled batch optimization with A/B testing
- **ConfigurationFactory interface**: Creates and validates configurations

### Key Features:
- Complete evolution cycle: evaluate → diagnose → mutate → test → select
- Convergence detection based on improvement thresholds
- Progress tracking with detailed metrics and callbacks
- Autonomous stopping conditions (max cycles, convergence, time limits)
- A/B testing capabilities for configuration comparison
- Comprehensive logging and debugging support

### Dependencies:
```yaml
dependencies:
  dartantic_evaluation: ^VERSION
  dartantic_evolution: ^VERSION  
  dartantic_diagnosis: ^VERSION
  logging: ^VERSION
```

### Implementation Details:
- SelfImprovementEngine should coordinate all other packages seamlessly
- Include proper convergence detection algorithms
- Support both streaming and batch optimization modes
- Add comprehensive callback system for monitoring
- Implement intelligent scheduling and resource management
- Include timeout and error recovery mechanisms
- Support custom optimization parameters and strategies

Please provide the complete package implementation with all files, including:
- lib/dartantic_optimization.dart (main export)
- lib/src/engines/ (optimization engine implementations)
- lib/src/orchestrators/ (orchestration patterns)
- lib/src/parameters/ (configuration and parameters)
- lib/src/results/ (result and progress tracking)
- example/autonomous_optimization.dart (complete self-improving system example)
- pubspec.yaml (package configuration)

Focus on robust coordination logic, comprehensive monitoring, and production-ready orchestration patterns.
```

---

## 📋 Implementation Guidelines

### For Each Package:

1. **Follow Dart conventions**: Use proper package structure with lib/, example/, and clear exports
2. **Include comprehensive tests**: Unit tests for all core functionality
3. **Add thorough documentation**: API docs, README, and usage examples  
4. **Handle errors gracefully**: Proper exception handling and validation
5. **Use logging effectively**: Structured logging for debugging and monitoring
6. **Maintain type safety**: Generic types where appropriate, null safety
7. **Follow dartantic patterns**: Integrate cleanly with existing dartantic_ai ecosystem

### Package Interdependencies:
- dartantic_evaluation: Foundation package (no dependencies on other self-improvement packages)
- dartantic_evolution: Depends on dartantic_evaluation for fitness assessment
- dartantic_diagnosis: Depends on dartantic_evaluation and dartantic_evolution for analysis
- dartantic_optimization: Top-level package depending on all others for coordination

### Testing Strategy:
- Each package should include comprehensive unit tests
- Integration tests should demonstrate cross-package functionality
- Include performance benchmarks for optimization algorithms
- Add examples that can serve as integration tests

Feed each prompt individually to Gemini 3 for focused implementation of each package.