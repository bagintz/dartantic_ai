# JSON-Based Workflow System Design

**Status:** Planning
**Owner:** Architecture Team
**Created:** 2025-11-23
**Target:** Dartantic Core v2.0

---

## Executive Summary

Design and implement a **use-agnostic, JSON-configurable workflow system** as a core Dartantic feature. This will enable declarative multi-agent workflow definitions without requiring code changes, making Dartantic accessible to a broader audience while maintaining full programmatic extensibility.

**Key Goals:**
- Move workflow configuration from code to JSON
- Keep core framework domain-agnostic
- Support evolutionary/genetic algorithm workflows
- Enable hot-reloading and A/B testing
- Maintain backward compatibility with code-based workflows

---

## Background & Motivation

### Current State

The restaurant recommendation sample (`samples/personalized_restaurant_recs/`) demonstrates a powerful evolutionary multi-agent workflow architecture:
- Multi-agent collaboration (planner, specialists, synthesizer)
- Genetic SOP evolution
- Pareto optimization across 6 dimensions
- Persona-driven personalization

**Problem:** This architecture is **hardcoded and sample-specific**. To create similar workflows for other domains (hiring, research papers, travel planning, etc.), users must:
1. Write significant Dart code
2. Understand complex orchestration patterns
3. Duplicate workflow logic across samples

### Vision

**Enable workflow definition via JSON configuration:**
```bash
# Users can create new workflows by editing JSON
samples/hiring_assistant/workflows/hiring.json
samples/paper_recommender/workflows/research.json
samples/travel_planner/workflows/itinerary.json
```

**Benefits:**
- ✅ Shareable workflow definitions (copy/paste between projects)
- ✅ Version control for workflow evolution
- ✅ Hot-reloading experiments without recompilation
- ✅ A/B testing multiple configurations
- ✅ Platform independence (potential Python/JS ports)
- ✅ Future: visual workflow editors

---

## Architecture Decision: Core vs. Samples

### What Goes in Core (`packages/dartantic_ai/`)

The core library provides **use-agnostic workflow primitives**:

#### 1. Workflow Schema & Parsing
```dart
// lib/src/workflows/workflow_definition.dart
class WorkflowDefinition {
  final String name;
  final String version;
  final List<AgentDefinition> agents;
  final List<PromptTemplate> promptTemplates;
  final ExecutionFlow executionFlow;
  final Map<String, dynamic> config;

  factory WorkflowDefinition.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

#### 2. Agent Definition
```dart
// lib/src/workflows/agent_definition.dart
class AgentDefinition {
  final String id;
  final String role;
  final String modelString;  // Reuses existing model resolution
  final String promptTemplateId;
  final bool enabled;
  final Map<String, dynamic> parameters;

  factory AgentDefinition.fromJson(Map<String, dynamic> json);
}
```

#### 3. Template Engine (Generic)
```dart
// lib/src/workflows/prompt_template.dart
class PromptTemplate {
  final String id;
  final String template;
  final List<String> requiredVariables;

  String render(Map<String, dynamic> context);

  // Supports: {{variable}}, {{object.property}}, {{list.0}}
  // Possibly also: {{#if condition}}, {{#each list}}, etc.
}
```

#### 4. Execution Flow (DAG-based)
```dart
// lib/src/workflows/execution_flow.dart
class ExecutionFlow {
  final String startNode;
  final List<ExecutionNode> nodes;
  final List<DataConnection> dataConnections;

  Stream<WorkflowEvent> execute({
    required Agent agent,
    required Map<String, dynamic> initialContext,
  });
}

abstract class ExecutionNode {
  final String id;
  final String type;

  factory ExecutionNode.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'agent': return AgentNode.fromJson(json);
      case 'parallel': return ParallelNode.fromJson(json);
      case 'conditional': return ConditionalNode.fromJson(json);
      case 'map': return MapNode.fromJson(json);
      default: throw UnsupportedNodeTypeException(json['type']);
    }
  }
}
```

#### 5. Configuration & Secrets
```dart
// lib/src/config/workflow_config.dart
class WorkflowConfig {
  final Map<String, String> secrets;      // Environment variable refs
  final Map<String, DataSource> dataSources;
  final Map<String, dynamic> parameters;

  // Resolve secrets: ${env:OPENAI_API_KEY}
  String resolveSecret(String key);

  // Resolve variables: ${config.key}, ${sop.parameter}
  dynamic resolveVariable(String expression, Map<String, dynamic> context);
}
```

#### 6. Data Source Registry (Extensible)
```dart
// lib/src/workflows/data_source.dart
abstract class DataSource {
  String get type;
  Future<dynamic> fetch(Map<String, dynamic> params);

  factory DataSource.fromJson(Map<String, dynamic> json) {
    return DataSourceRegistry.instance.create(json['type'], json);
  }
}

class DataSourceRegistry {
  static final instance = DataSourceRegistry._();

  final Map<String, DataSourceFactory> _factories = {};

  void register(String type, DataSourceFactory factory);
  DataSource create(String type, Map<String, dynamic> config);
}
```

#### 7. Workflow Executor
```dart
// lib/src/workflows/workflow_executor.dart
class WorkflowExecutor {
  final WorkflowDefinition workflow;
  final Agent agent;

  Stream<WorkflowEvent> execute({
    required Map<String, dynamic> initialContext,
    WorkflowExecutorOptions? options,
  }) async* {
    final config = WorkflowConfig.fromJson(workflow.config);
    final context = ExecutionContext(
      initialData: initialContext,
      config: config,
      dataSources: _buildDataSources(),
    );

    yield* workflow.executionFlow.execute(
      agent: agent,
      context: context,
    );
  }
}
```

#### 8. Evolutionary/Genetic Algorithm Support
```dart
// lib/src/workflows/genome.dart
class GenomeDefinition {
  final List<GenomeParameter> parameters;

  // Create SOP instance from JSON config
  Map<String, dynamic> toSOP();

  factory GenomeDefinition.fromJson(Map<String, dynamic> json);
}

class GenomeParameter {
  final String name;
  final String type;  // 'integer', 'boolean', 'string', 'enum'
  final dynamic defaultValue;
  final bool mutable;
  final Map<String, dynamic> mutationRules;
}

// lib/src/workflows/mutation_strategy.dart
abstract class MutationStrategy {
  String get type;
  Map<String, dynamic> mutate(Map<String, dynamic> sop);

  factory MutationStrategy.fromJson(Map<String, dynamic> json) {
    return MutationStrategyRegistry.instance.create(json['type'], json);
  }
}
```

#### 9. Evaluation Framework
```dart
// lib/src/workflows/evaluation.dart
class EvaluationDefinition {
  final List<EvaluationDimension> dimensions;

  Future<EvaluationResult> evaluate({
    required String output,
    required Map<String, dynamic> context,
  });

  factory EvaluationDefinition.fromJson(Map<String, dynamic> json);
}

abstract class EvaluationDimension {
  final String name;
  final double weight;
  final String type;  // 'llm_judged', 'programmatic', 'custom'

  Future<double> score(String output, Map<String, dynamic> context);

  factory EvaluationDimension.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'llm_judged': return LlmJudgedDimension.fromJson(json);
      case 'programmatic': return ProgrammaticDimension.fromJson(json);
      case 'custom': return CustomDimension.fromJson(json);
      default: throw UnsupportedDimensionTypeException(json['type']);
    }
  }
}
```

### What Stays in Samples

Sample applications provide **domain-specific implementations**:

#### 1. Domain Models
```dart
// samples/personalized_restaurant_recs/lib/src/models/
class Restaurant { ... }
class Review { ... }
class UserPersona { ... }
```

#### 2. Custom Data Sources
```dart
// samples/personalized_restaurant_recs/lib/src/data/
class YelpJsonDataSource extends DataSource {
  @override
  String get type => 'yelp_json';

  @override
  Future<List<Review>> fetch(Map<String, dynamic> params) async {
    // Yelp-specific loading logic
  }
}

// Registration in main.dart:
void main() {
  DataSourceRegistry.instance.register(
    'yelp_json',
    (config) => YelpJsonDataSource(config),
  );

  // Load workflow
  final workflow = WorkflowDefinition.fromJson(
    jsonDecode(File('workflows/restaurant.json').readAsStringSync()),
  );

  runApp(MyApp(workflow: workflow));
}
```

#### 3. Custom Evaluation Functions
```dart
// samples/personalized_restaurant_recs/lib/src/evaluation/
class PersonaMentionScorer extends CustomEvaluationFunction {
  @override
  String get name => 'persona_mention_analysis';

  @override
  double score(EvaluationContext context) {
    // Domain-specific scoring
  }
}
```

#### 4. Workflow JSON Configuration
```json
// samples/personalized_restaurant_recs/workflows/restaurant.json
{
  "workflow": {
    "name": "Restaurant Analysis Workflow",
    "version": "1.0"
  },
  "config": {
    "data_sources": {
      "reviews": {
        "type": "yelp_json",
        "path": "tmp_docs/yelp_academic_dataset_review.json"
      }
    }
  },
  "agents": [...],
  "execution_flow": {...}
}
```

---

## Proposed JSON Schema Structure

### Complete Example Workflow

```json
{
  "workflow": {
    "name": "Restaurant Analysis Workflow",
    "version": "1.0",
    "description": "Self-improving multi-agent restaurant recommendation system"
  },

  "config": {
    "secrets": {
      "openai_api_key": "${env:OPENAI_API_KEY}",
      "anthropic_api_key": "${env:ANTHROPIC_API_KEY}"
    },
    "data_sources": {
      "primary": {
        "type": "yelp_json",
        "path": "tmp_docs/yelp_academic_dataset_review.json",
        "fallback": {
          "type": "synthetic",
          "generator": "DataProvider",
          "seed": 42
        }
      }
    },
    "parameters": {
      "max_reviews": 50,
      "min_rating": 3.0
    }
  },

  "agents": [
    {
      "id": "planner",
      "role": "analysis_planner",
      "model": "gpt-4o-mini",
      "prompt_template_id": "planner_prompt",
      "enabled": true
    },
    {
      "id": "data_analyst",
      "role": "data_analyst",
      "model": "gpt-4o-mini",
      "prompt_template_id": "data_analyst_prompt",
      "enabled_by_sop": "useDataAnalyst",
      "parallel": true
    },
    {
      "id": "service_analyst",
      "role": "service_analyst",
      "model": "gpt-4o-mini",
      "prompt_template_id": "service_analyst_prompt",
      "enabled_by_sop": "useServiceAnalyst",
      "parallel": true
    },
    {
      "id": "sentiment_analyst",
      "role": "sentiment_analyst",
      "model": "gpt-4o-mini",
      "prompt_template_id": "sentiment_analyst_prompt",
      "enabled": true,
      "parallel": true
    },
    {
      "id": "synthesizer",
      "role": "synthesizer",
      "model": "${sop.synthesizerModel}",
      "prompt_template_id": "synthesizer_prompt",
      "enabled": true
    }
  ],

  "prompt_templates": {
    "planner_prompt": "You are a restaurant analysis planner coordinating a PERSONALIZED review analysis.\n\nUser Persona: {{persona.name}}\nUser Description: {{persona.description}}\nUser Priorities: {{persona.priorities}}\n\nRestaurant: {{restaurant.name}}\n\nCreate an analysis plan focused on what THIS USER cares about.",

    "data_analyst_prompt": "You are a data analyst evaluating restaurant reviews FOR A SPECIFIC USER.\n\nUser Persona: {{persona.name}}\nRestaurant: {{restaurant.name}}\nAnalysis Plan: {{plan}}\n\nReviews:\n{{reviews}}\n\nExtract key statistics and patterns RELEVANT TO THIS USER.",

    "synthesizer_prompt": "Synthesize the analysis results into a PERSONALIZED recommendation.\n\nUser: {{persona.name}}\nRestaurant: {{restaurant.name}}\nAnalyses: {{analyses}}\n\nBe honest - if the restaurant doesn't match the user's persona, say so clearly."
  },

  "execution_flow": {
    "start": "planner",
    "nodes": [
      {
        "id": "planner",
        "type": "agent",
        "agent_id": "planner",
        "inputs": {
          "restaurant": "${context.restaurant}",
          "persona": "${context.persona}",
          "reviews": "${context.reviews}"
        },
        "outputs": ["plan"],
        "next": "specialists"
      },
      {
        "id": "specialists",
        "type": "parallel",
        "agents": ["data_analyst", "service_analyst", "sentiment_analyst"],
        "inputs": {
          "plan": "${planner.plan}",
          "restaurant": "${context.restaurant}",
          "persona": "${context.persona}",
          "reviews": "${context.reviews}"
        },
        "outputs": ["analyses"],
        "next": "synthesizer"
      },
      {
        "id": "synthesizer",
        "type": "agent",
        "agent_id": "synthesizer",
        "inputs": {
          "analyses": "${specialists.analyses}",
          "restaurant": "${context.restaurant}",
          "persona": "${context.persona}"
        },
        "outputs": ["recommendation"],
        "next": "end"
      }
    ]
  },

  "genome": {
    "parameters": [
      {
        "name": "plannerPrompt",
        "type": "string",
        "default": "${prompt_templates.planner_prompt}",
        "mutable": true,
        "mutation_type": "prompt_enhancement"
      },
      {
        "name": "reviewRetrieverK",
        "type": "integer",
        "default": 5,
        "min": 3,
        "max": 15,
        "mutable": true,
        "mutation_delta": 2
      },
      {
        "name": "synthesizerModel",
        "type": "string",
        "default": "gpt-4o-mini",
        "options": ["gpt-4o-mini", "gpt-4o", "claude-3-5-sonnet-20241022"],
        "mutable": true
      },
      {
        "name": "useDataAnalyst",
        "type": "boolean",
        "default": true,
        "mutable": true
      },
      {
        "name": "useServiceAnalyst",
        "type": "boolean",
        "default": false,
        "mutable": true
      },
      {
        "name": "personalizationLevel",
        "type": "enum",
        "default": "medium",
        "options": ["low", "medium", "high"],
        "mutable": true
      }
    ]
  },

  "evolution": {
    "population_size": 6,
    "max_generations": 3,
    "elite_count": 2,
    "mutation_strategies": [
      {
        "type": "parameter_tweak",
        "weight": 0.33,
        "parameters": ["reviewRetrieverK"]
      },
      {
        "type": "structural_mutation",
        "weight": 0.33,
        "parameters": ["useDataAnalyst", "useServiceAnalyst", "personalizationLevel"]
      },
      {
        "type": "prompt_enhancement",
        "weight": 0.34,
        "parameters": ["plannerPrompt", "synthesizerPrompt"],
        "enhancements": [
          "Add example formatting",
          "Emphasize specific priorities",
          "Request structured output",
          "Add constraint checking"
        ]
      }
    ],
    "selection_strategy": {
      "type": "pareto",
      "objectives": ["maximize_scores", "maintain_diversity"]
    }
  },

  "evaluation": {
    "dimensions": [
      {
        "name": "accuracy",
        "type": "llm_judged",
        "weight": 0.166,
        "judge_model": "gpt-4o",
        "prompt_template_id": "accuracy_judge_prompt"
      },
      {
        "name": "completeness",
        "type": "llm_judged",
        "weight": 0.166,
        "judge_model": "gpt-4o",
        "prompt_template_id": "completeness_judge_prompt"
      },
      {
        "name": "helpfulness",
        "type": "llm_judged",
        "weight": 0.166,
        "judge_model": "gpt-4o",
        "prompt_template_id": "helpfulness_judge_prompt"
      },
      {
        "name": "conciseness",
        "type": "programmatic",
        "weight": 0.166,
        "function": "word_count_distance",
        "parameters": {
          "optimal_words": 150,
          "acceptable_range": 50,
          "penalty_per_word": 0.01
        }
      },
      {
        "name": "data_grounding",
        "type": "programmatic",
        "weight": 0.166,
        "function": "review_quote_ratio",
        "parameters": {
          "optimal_ratio": 0.3,
          "minimum_quotes": 2
        }
      },
      {
        "name": "personalization",
        "type": "custom",
        "weight": 0.172,
        "function": "persona_mention_analysis",
        "parameters": {
          "required_mentions": ["persona.name"],
          "priority_coverage_threshold": 0.5
        }
      }
    ]
  }
}
```

### Schema Design Principles

#### 1. Variable Interpolation
Support multiple interpolation syntaxes:
- **Environment variables:** `${env:OPENAI_API_KEY}`
- **Config parameters:** `${config.max_reviews}`
- **SOP/genome values:** `${sop.synthesizerModel}`
- **Runtime context:** `${context.restaurant}`, `${context.persona}`
- **Node outputs:** `${planner.plan}`, `${specialists.analyses}`
- **Template references:** `${prompt_templates.planner_prompt}`

#### 2. Data Flow
Two approaches for passing data between nodes:

**Explicit (Open Agent Spec style):**
```json
"data_flow_connections": [
  {
    "source_node": "planner",
    "source_output": "plan",
    "destination_node": "data_analyst",
    "destination_input": "plan"
  }
]
```

**Inline (n8n style):**
```json
"inputs": {
  "plan": "${planner.plan}"
}
```

**Recommendation:** Support both. Inline for simple cases, explicit for complex graphs.

#### 3. Conditional Logic
```json
{
  "id": "quality_check",
  "type": "conditional",
  "condition": "${evaluation.score} > 0.8",
  "true_branch": "approve_node",
  "false_branch": "revision_node"
}
```

#### 4. Parallel Execution
```json
{
  "id": "specialists",
  "type": "parallel",
  "agents": ["data_analyst", "service_analyst", "sentiment_analyst"],
  "merge_strategy": "map"
}
```

#### 5. Map/Reduce Operations
```json
{
  "id": "analyze_all_restaurants",
  "type": "map",
  "agent_id": "analyzer",
  "input_list": "${context.restaurants}",
  "output_key": "analyses"
}
```

---

## Implementation Phases

### Phase 1: Core Schema Design (2-3 weeks) ← START HERE

**Goal:** Define and validate the complete JSON schema before writing implementation code.

**Deliverables:**
1. **JSON Schema Definition** (`packages/dartantic_ai/schema/workflow.schema.json`)
   - Complete JSON Schema v7 definition
   - All workflow components (agents, nodes, templates, etc.)
   - Validation rules and constraints
   - Type definitions

2. **Example Workflow Configurations** (`packages/dartantic_ai/examples/workflows/`)
   - `minimal.json` - Simplest possible workflow (single agent)
   - `sequential.json` - Multi-agent sequential workflow
   - `parallel.json` - Parallel agent execution
   - `conditional.json` - Branching logic
   - `evolutionary.json` - Full SOP evolution example

3. **Schema Documentation** (`wiki/JSON-Workflow-Schema-Spec.md`)
   - Complete reference documentation
   - Every field explained with examples
   - Variable interpolation rules
   - Data flow patterns
   - Extension points (custom nodes, data sources, evaluators)

4. **Validation Strategy**
   - How to validate workflow JSON against schema
   - Runtime validation approach
   - Error message design (helpful, actionable)

**Success Criteria:**
- [ ] JSON Schema covers all identified use cases
- [ ] Example workflows represent common patterns
- [ ] Schema is reviewable by stakeholders
- [ ] Extension points are clearly defined
- [ ] Migration path from current code-based workflows is clear

**Key Design Questions to Resolve:**

1. **Template Engine Choice:**
   - Option A: Mustache `{{variable}}`
   - Option B: Jinja2 `{{ variable }}` with logic
   - Option C: Custom DSL
   - **Recommendation:** Start with Mustache, add logic if needed

2. **Node Type Hierarchy:**
   - What base node types do we need?
   - How extensible should node definitions be?
   - Should samples be able to register custom node types?

3. **Data Source Interface:**
   - How generic should the data source contract be?
   - Sync vs async fetching?
   - Streaming support?

4. **Error Handling:**
   - How do workflows handle agent errors?
   - Retry policies?
   - Fallback strategies?

5. **Versioning:**
   - Workflow version compatibility?
   - Schema evolution strategy?
   - Backward compatibility guarantees?

### Phase 2: Core Implementation (2-3 weeks)

**Goal:** Implement the workflow engine in `packages/dartantic_ai/`.

**Tasks:**
1. **Week 1:** Schema parsing and validation
   - `WorkflowDefinition`, `AgentDefinition`, `PromptTemplate`
   - JSON deserialization with validation
   - Error reporting

2. **Week 2:** Execution engine
   - `ExecutionFlow` and `ExecutionNode` hierarchy
   - Sequential, parallel, conditional nodes
   - Data passing and context management
   - Template rendering with variable interpolation

3. **Week 3:** Configuration and extensibility
   - Secret/environment variable resolution
   - Data source registry
   - Custom function registry
   - Streaming event system

**Success Criteria:**
- [ ] All example workflows execute successfully
- [ ] Unit tests for each component
- [ ] Integration tests for end-to-end workflows
- [ ] Performance benchmarks (minimal overhead vs code-based)

### Phase 3: Evolution Support (1-2 weeks)

**Goal:** Add genetic algorithm / SOP evolution support to workflow system.

**Tasks:**
1. Genome definition and parsing
2. Mutation strategy registry
3. Selection strategy integration
4. Evaluation framework
5. Evolution engine integration

**Success Criteria:**
- [ ] Evolutionary workflows match current restaurant sample behavior
- [ ] New samples can define custom mutation strategies
- [ ] Pareto optimization works with JSON-defined evaluations

### Phase 4: Restaurant Sample Migration (1 week)

**Goal:** Migrate existing restaurant sample to use JSON workflow system.

**Tasks:**
1. Extract domain-specific code (models, data sources)
2. Register custom components
3. Convert workflow to `restaurant.json`
4. Verify parity with original implementation
5. Update tests

**Success Criteria:**
- [ ] Functionality identical to original
- [ ] No regressions in performance or quality
- [ ] Code is significantly simpler (less orchestration logic)
- [ ] Workflow is understandable by reading JSON

### Phase 5: Documentation & Examples (1 week)

**Goal:** Make the system accessible to users.

**Tasks:**
1. Core workflow system documentation
2. "Getting Started" tutorial
3. Extension guide (custom nodes, data sources, evaluators)
4. Migration guide (code-based → JSON-based)
5. Sample project templates for all 6 domains

**Success Criteria:**
- [ ] New user can create simple workflow in < 1 hour
- [ ] Sample projects demonstrate diverse patterns
- [ ] Extension points are well-documented
- [ ] Migration path is clear

---

## Open Design Questions

### 1. Template Engine Complexity
**Question:** How much logic should templates support?

**Options:**
- **Simple (Mustache):** Just variable interpolation `{{variable}}`
- **Medium (Handlebars):** Add `{{#if}}`, `{{#each}}`, helpers
- **Complex (Jinja2):** Full programming language in templates

**Trade-offs:**
- Simple: Easy to implement, less powerful
- Complex: More flexible, but users write code in strings

**Recommendation:** Start simple (Mustache), evaluate need for logic after Phase 4.

### 2. Workflow Composition
**Question:** Should workflows be able to call sub-workflows?

**Use Case:**
```json
{
  "id": "sub_analysis",
  "type": "workflow",
  "workflow_path": "workflows/detailed_analysis.json",
  "inputs": {...}
}
```

**Trade-offs:**
- Pro: Reusability, modularity
- Con: Complexity, debugging challenges

**Recommendation:** Defer to Phase 2, evaluate during implementation.

### 3. Real-time Workflow Updates
**Question:** Should running workflows react to JSON changes?

**Use Case:** Hot-reloading during development

**Trade-offs:**
- Pro: Fast experimentation
- Con: Consistency issues, complex state management

**Recommendation:** Not for v1. Requires careful state management design.

### 4. Visual Workflow Editor
**Question:** Should we build a UI for editing workflows?

**Options:**
- Command-line wizard
- Web-based visual editor (like n8n)
- VSCode extension

**Recommendation:** Not for v1. Focus on JSON schema quality first.

### 5. Cross-Language Support
**Question:** Should JSON workflows be executable from other languages?

**Vision:** Same workflow JSON runs in Dart, Python, JavaScript

**Requirements:**
- Standard schema
- Language-specific runtime implementations
- Cross-language data serialization

**Recommendation:** Design schema with this in mind, but implement Dart-only for v1.

---

## Success Metrics

### Quantitative
- [ ] 10+ example workflows covering diverse domains
- [ ] 90%+ code reduction in sample orchestration logic
- [ ] < 10% performance overhead vs code-based workflows
- [ ] JSON schema passes validation with all major validators

### Qualitative
- [ ] New contributors can create workflows without understanding Dart orchestration
- [ ] Workflows are self-documenting (readable JSON)
- [ ] Extension points are clear and well-used
- [ ] Community creates workflows we didn't anticipate

---

## AI Agent Instructions

**Your task is to complete Phase 1: Core Schema Design**

### Step 1: Create JSON Schema Definition

Create `packages/dartantic_ai/schema/workflow.schema.json` with a complete JSON Schema v7 definition covering:

1. **Workflow Metadata**
   - `name`, `version`, `description`
   - Versioning strategy

2. **Configuration Section**
   - Secrets (environment variable references)
   - Data sources (type registry pattern)
   - Parameters (workflow-level configuration)

3. **Agents Section**
   - Agent definitions with IDs, roles, models
   - Prompt template references
   - Enable conditions (static and SOP-driven)
   - Parallel execution flags

4. **Prompt Templates Section**
   - Template ID → template string mapping
   - Variable declarations
   - Template inheritance (optional)

5. **Execution Flow Section**
   - Node definitions (agent, parallel, conditional, map, custom)
   - Data flow (inputs/outputs)
   - Control flow (next node, branching)
   - Variable interpolation syntax

6. **Genome Section (Optional)**
   - Parameter definitions for evolution
   - Mutation rules per parameter
   - Default values and constraints

7. **Evolution Section (Optional)**
   - Population parameters
   - Mutation strategy configurations
   - Selection strategy configuration

8. **Evaluation Section (Optional)**
   - Dimension definitions
   - LLM-judged vs programmatic vs custom
   - Weights and scoring parameters

### Step 2: Create Example Workflows

Create 5 example workflows in `packages/dartantic_ai/examples/workflows/`:

1. **minimal.json** - Single agent, no templating
   - Purpose: Simplest possible workflow
   - Pattern: One-shot agent call

2. **sequential.json** - Three agents in sequence
   - Purpose: Demonstrate data passing
   - Pattern: agent1 → agent2 → agent3

3. **parallel.json** - Multiple agents running in parallel
   - Purpose: Demonstrate concurrent execution
   - Pattern: agent1 → [agent2a, agent2b, agent2c] → agent3

4. **conditional.json** - Branching based on output
   - Purpose: Demonstrate control flow
   - Pattern: agent1 → if(condition) ? agent2a : agent2b

5. **evolutionary.json** - Full SOP evolution workflow
   - Purpose: Demonstrate genetic algorithm integration
   - Pattern: Complete restaurant-style workflow with genome

### Step 3: Write Schema Documentation

Create `wiki/JSON-Workflow-Schema-Spec.md` with:

1. **Overview**
   - Purpose and goals
   - When to use JSON vs code-based workflows

2. **Schema Reference**
   - Every top-level section explained
   - Every field documented with type, purpose, examples
   - Required vs optional fields

3. **Variable Interpolation**
   - Complete syntax reference
   - `${env:VAR}`, `${config.key}`, `${node.output}`, etc.
   - Scoping rules

4. **Node Types**
   - Complete reference for all node types
   - When to use each type
   - Configuration examples

5. **Extension Points**
   - How to register custom data sources
   - How to register custom evaluation functions
   - How to add custom node types (future)

6. **Common Patterns**
   - Multi-agent collaboration
   - Parallel processing
   - Conditional routing
   - Map/reduce operations
   - Error handling

7. **Best Practices**
   - Workflow organization
   - Naming conventions
   - Prompt template design
   - Secret management

### Step 4: Address Design Questions

For each open design question in this document, provide:
1. Your analysis of the options
2. Concrete examples showing implications
3. Your recommendation with rationale
4. Potential future evolution path

Write these as decision records in `wiki/decisions/`.

### Step 5: Validation Strategy

Document in `wiki/JSON-Workflow-Validation.md`:
1. How workflows are validated at load time
2. Runtime validation approach
3. Error message design principles
4. Example error messages (good vs bad)

---

## Reference Material

### Industry Research

This design is informed by three mature declarative workflow systems:

#### 1. n8n Workflow Automation (JSON-based)
- Node-based structure with unique IDs
- Expression syntax for data passing: `={{ $('NodeName').json.field }}`
- Credential management via references
- Visual editor (shows value of well-designed JSON)
- [n8n Documentation](https://docs.n8n.io/)

#### 2. Apache Airflow DAG Factory (YAML-based)
- Task dependency declarations: `dependencies: [task1, task2]`
- Data passing with `+task_id` syntax
- Asset-based reactive scheduling
- Configuration inheritance
- [DAG Factory Docs](https://github.com/astronomer/dag-factory)

#### 3. Open Agent Specification (Agent Spec) (YAML/JSON)
- Framework-agnostic agent definitions
- Separation of control flow and data flow
- Component reusability: `$component_ref`
- Strong typing with JSON Schema
- [Agent Spec GitHub](https://github.com/oracle/agent-spec)

### Current Dartantic Patterns

Study these existing files to understand current architecture:

- **SOP Serialization:** `samples/personalized_restaurant_recs/lib/src/config/restaurant_analysis_sop.dart` (lines 82-110)
  - Already has `toJson()` and `fromJson()`
  - Good model for genome definition

- **Workflow Orchestration:** `samples/personalized_restaurant_recs/lib/src/workflows/restaurant_analysis_workflow.dart`
  - Shows sequential + parallel pattern
  - Prompt building that should become templates
  - Data passing between agents

- **Evolution Engine:** `samples/personalized_restaurant_recs/lib/src/evolution/evolution_engine.dart`
  - Genetic algorithm that needs to work with JSON configs
  - Mutation and selection strategies to externalize

- **Evaluation System:** `samples/personalized_restaurant_recs/lib/src/evaluation/restaurant_evaluator.dart`
  - Mix of LLM-judged and programmatic scoring
  - Six-dimensional evaluation to generalize

---

## Context for AI Agent

You are designing the **core schema** for a JSON-based workflow system that will become a foundational feature of Dartantic AI. Your work will enable:

1. **Accessibility:** Users can create complex multi-agent workflows without writing orchestration code
2. **Reusability:** Workflow definitions can be shared, versioned, and evolved
3. **Flexibility:** Both simple and complex workflows (including genetic algorithms) are supported
4. **Extensibility:** Samples can register domain-specific components

**Key Principles:**
- **Use-agnostic:** Schema has no knowledge of restaurants, hiring, papers, etc.
- **Declarative:** Workflows describe "what" not "how"
- **Type-safe:** JSON Schema validation catches errors early
- **Self-documenting:** Workflows should be understandable by reading JSON
- **Migration-friendly:** Path from code-based to JSON-based should be clear

**Start with the schema design** (Phase 1). Do not implement Dart code yet. Focus on:
1. Getting the JSON structure right
2. Creating clear, comprehensive examples
3. Writing excellent documentation
4. Addressing the open design questions

Your schema will be reviewed by stakeholders before implementation begins. Make it count!

---

## Questions or Concerns?

If you encounter ambiguity or need clarification:
1. Document your assumptions in `wiki/decisions/assumptions.md`
2. Create alternatives for stakeholder review
3. Use examples to illustrate trade-offs
4. Recommend a path forward with clear rationale

Good luck! You're building the foundation for a powerful new capability in Dartantic.
