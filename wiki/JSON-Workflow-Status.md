# JSON Workflow System - Current Status

**Date:** 2025-11-28
**Branch:** dartantic_rag_flow
**Status:** Design Complete, Implementation Not Started

---

## Executive Summary

We have completed the **design phase** for a JSON-based workflow system that will make Dartantic's multi-agent workflows accessible without writing code. The design specification is complete and merged, but **implementation has not yet begun**.

---

## ✅ What's Been Completed

### 1. Personalization Fixes ✅

**Location:** `samples/personalized_restaurant_recs/lib/src/workflows/restaurant_analysis_workflow.dart`

- All specialist agents now use persona context
- Data Analyst filters statistics/patterns by user priorities
- Service Analyst analyzes service aspects relevant to user
- Sentiment Analyst filters sentiment for persona priorities
- Improved baseline prompts emphasizing personalization

**Impact:** Fixed critical bug where Family-Oriented users could receive bar recommendations.

### 2. UI Prompt Editor ✅

**Location:** `samples/personalized_restaurant_recs/lib/main.dart`

- Text controllers for planner and synthesizer prompts (lines 90-91)
- TextField widgets in Advanced Configuration section (lines 896+)
- Custom baseline creation from UI (line 415)
- Users can now experiment with prompt engineering without editing code

### 3. SOP JSON Serialization ✅

**Location:** `samples/personalized_restaurant_recs/lib/src/config/restaurant_analysis_sop.dart`

- `RestaurantAnalysisSOP.toJson()` (lines 82-95)
- `RestaurantAnalysisSOP.fromJson()` (lines 97-110)
- All 8 SOP parameters are serializable:
  - plannerPrompt
  - reviewRetrieverK
  - synthesizerPrompt
  - synthesizerModel
  - useDataAnalyst
  - useServiceAnalyst
  - personalizationLevel
  - generation + parentId (for evolution tracking)

**Status:** Already implemented - this is the "genome" for evolution.

### 4. Design Documentation ✅

**Location:** `wiki/JSON-Workflow-System-Design.md` (1,130 lines)

Complete specification including:
- Architecture decision: Core vs. Samples separation
- Full JSON schema structure example
- 5-phase implementation plan
- Open design questions
- AI agent instructions for Phase 1
- Industry research (n8n, Airflow, Open Agent Spec)

**Location:** `samples/personalized_restaurant_recs/SAMPLE_PROJECT_IDEAS.md` (359 lines)

Six diverse project ideas showing how to apply the architecture:
1. Personalized Hiring Assistant (GitHub, Stack Overflow data)
2. Academic Research Paper Recommender (ArXiv, PubMed)
3. Medical Treatment Path Advisor (ClinicalTrials.gov)
4. Legal Precedent Finder (Court case databases)
5. E-commerce Product Recommender (Amazon reviews)
6. Travel Itinerary Planner (TripAdvisor, Google Maps)

---

## ❌ What Hasn't Started Yet (JSON Workflow Implementation)

### Phase 1: Core Schema Design (Not Started)

**Target:** `packages/dartantic_ai/schema/workflow.schema.json`
- **Status:** Does not exist
- **Need:** JSON Schema v7 definition for workflow configurations

**Target:** `packages/dartantic_ai/examples/workflows/`
- **Status:** Directory does not exist
- **Need:** 5 example workflow JSONs:
  - `minimal.json` - Single agent workflow
  - `sequential.json` - Multi-agent sequential
  - `parallel.json` - Parallel execution
  - `conditional.json` - Branching logic
  - `evolutionary.json` - Full SOP evolution

**Target:** `wiki/JSON-Workflow-Schema-Spec.md`
- **Status:** Does not exist
- **Need:** Complete schema reference documentation

### Phase 2-5: Implementation (Not Started)

- Core workflow engine classes
- Execution flow and node types
- Template rendering system
- Data source registry
- Evolution support integration
- Restaurant sample migration
- Documentation and tutorials

---

## Current Architecture (Code-Based)

### How It Works Now

```dart
// samples/personalized_restaurant_recs/lib/src/workflows/restaurant_analysis_workflow.dart
class RestaurantAnalysisWorkflow {
  Future<String> run({
    required Restaurant restaurant,
    required List<Review> reviews,
    required UserPersona persona,
    required RestaurantAnalysisSOP sop,
  }) async {
    // Step 1: Planner (hardcoded)
    final plan = await _runPlanner(
      restaurant: restaurant,
      persona: persona,
      sop: sop,
    );

    // Step 2: Specialists in parallel (hardcoded structure)
    final analyses = <String, String>{};
    if (sop.useDataAnalyst) {
      analyses['data'] = await _runDataAnalyst(...);
    }
    if (sop.useServiceAnalyst) {
      analyses['service'] = await _runServiceAnalyst(...);
    }
    analyses['sentiment'] = await _runSentimentAnalyst(...);

    // Step 3: Synthesizer (hardcoded)
    final recommendation = await _runSynthesizer(...);

    return recommendation;
  }
}
```

**Characteristics:**
- Workflow structure is **hardcoded in Dart**
- Agent prompts are **string templates in code**
- Execution order is **programmatic logic**
- To create a new domain, you must **write a new workflow class**

### What Works Well

✅ SOP parameters (genome) are configurable and evolvable
✅ Prompts can be edited in UI
✅ Agent models are configurable
✅ Evolution works perfectly

### What's Hardcoded

❌ Which agents run (data analyst, service analyst, sentiment analyst)
❌ Execution order (planner → specialists → synthesizer)
❌ Parallel vs sequential execution
❌ Data flow between agents
❌ Prompt templates (stored in code, not external config)

---

## Target Architecture (JSON-Based)

### How It Would Work

```json
// samples/personalized_restaurant_recs/workflows/restaurant.json
{
  "workflow": {
    "name": "Restaurant Analysis Workflow",
    "version": "1.0"
  },

  "agents": [
    {
      "id": "planner",
      "role": "analysis_planner",
      "model": "gpt-4o-mini",
      "prompt_template_id": "planner_prompt"
    },
    {
      "id": "data_analyst",
      "role": "data_analyst",
      "model": "gpt-4o-mini",
      "enabled_by_sop": "useDataAnalyst",
      "parallel": true
    }
  ],

  "prompt_templates": {
    "planner_prompt": "You are a restaurant analysis planner...\n\nUser Persona: {{persona.name}}\n..."
  },

  "execution_flow": {
    "start": "planner",
    "nodes": [
      {
        "id": "planner",
        "type": "agent",
        "agent_id": "planner",
        "next": "specialists"
      },
      {
        "id": "specialists",
        "type": "parallel",
        "agents": ["data_analyst", "service_analyst", "sentiment_analyst"],
        "next": "synthesizer"
      },
      {
        "id": "synthesizer",
        "type": "agent",
        "agent_id": "synthesizer"
      }
    ]
  }
}
```

### What Would Be Configurable

✅ Which agents run (defined in JSON)
✅ Execution order (DAG in JSON)
✅ Parallel vs sequential (node type in JSON)
✅ Data flow between agents (explicit in JSON)
✅ Prompt templates (external, with variable interpolation)
✅ Agent models (string references)
✅ Data sources (registry pattern)

### Benefits

1. **No Code Required:** Create hiring assistant by writing `hiring.json`
2. **Hot Reloadable:** Edit JSON and restart, no recompilation
3. **Shareable:** Copy/paste workflow configs between projects
4. **Version Control:** Track workflow evolution in git
5. **A/B Testing:** Run multiple configs in parallel
6. **Platform Independent:** Same JSON could work in Python/JS ports

---

## Key Files Reference

### Design Documentation

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| `wiki/JSON-Workflow-System-Design.md` | 1,130 | Complete design spec with 5-phase plan | ✅ Complete |
| `samples/personalized_restaurant_recs/SAMPLE_PROJECT_IDEAS.md` | 359 | 6 diverse project ideas | ✅ Complete |
| `wiki/JSON-Workflow-Schema-Spec.md` | - | Schema reference docs | ❌ Not created |

### Current Implementation

| File | Purpose | JSON Support |
|------|---------|--------------|
| `samples/personalized_restaurant_recs/lib/src/config/restaurant_analysis_sop.dart` | SOP genome definition | ✅ Full JSON serialization |
| `samples/personalized_restaurant_recs/lib/src/workflows/restaurant_analysis_workflow.dart` | Workflow orchestration | ❌ Hardcoded in Dart |
| `samples/personalized_restaurant_recs/lib/main.dart` | UI with prompt editors | ✅ Prompts editable |

### Target Implementation (Not Created)

| File | Purpose | Status |
|------|---------|--------|
| `packages/dartantic_ai/schema/workflow.schema.json` | JSON Schema v7 definition | ❌ Not created |
| `packages/dartantic_ai/lib/src/workflows/workflow_definition.dart` | Core workflow classes | ❌ Not created |
| `packages/dartantic_ai/lib/src/workflows/execution_flow.dart` | DAG execution engine | ❌ Not created |
| `packages/dartantic_ai/examples/workflows/minimal.json` | Example workflow | ❌ Not created |

---

## The Gap: What's Missing

### Current State
```dart
// To create a hiring assistant, you'd need to:
// 1. Write a new HiringWorkflow class in Dart
// 2. Implement _runPlanner, _runCodeAnalyst, _runCollaborationAnalyst, etc.
// 3. Hardcode the execution flow
// 4. Duplicate orchestration logic from restaurant sample
```

### Desired State
```json
// To create a hiring assistant, you'd write:
// samples/hiring_assistant/workflows/hiring.json
{
  "agents": [...],
  "execution_flow": {...}
}

// Then register domain-specific data sources:
DataSourceRegistry.instance.register('github_api', GitHubDataSource);
```

**Effort Reduction:** From ~500 lines of orchestration code → ~100 lines JSON config

---

## Implementation Roadmap

### Phase 1: Core Schema Design (2-3 weeks) ← **START HERE**

**Deliverables:**
1. JSON Schema definition (`packages/dartantic_ai/schema/workflow.schema.json`)
2. 5 example workflows (`packages/dartantic_ai/examples/workflows/`)
3. Schema documentation (`wiki/JSON-Workflow-Schema-Spec.md`)
4. Design decision records for open questions

**Status:** Not started
**Blocking:** None - design doc is complete

### Phase 2: Core Implementation (2-3 weeks)

**Deliverables:**
1. Workflow parsing and validation
2. Execution engine (sequential, parallel, conditional nodes)
3. Template rendering with variable interpolation
4. Data source registry

**Status:** Not started
**Blocking:** Requires Phase 1 schema

### Phase 3: Evolution Support (1-2 weeks)

**Deliverables:**
1. Genome definition in JSON
2. Mutation strategy registry
3. Evaluation framework integration

**Status:** Not started
**Blocking:** Requires Phase 2 core engine

### Phase 4: Restaurant Sample Migration (1 week)

**Deliverables:**
1. Convert `restaurant_analysis_workflow.dart` to `restaurant.json`
2. Register custom data sources (Yelp, synthetic)
3. Register custom evaluation functions
4. Verify parity with original

**Status:** Not started
**Blocking:** Requires Phase 3 evolution support

### Phase 5: Documentation & Examples (1 week)

**Deliverables:**
1. Getting started tutorial
2. Extension guide (custom nodes, data sources)
3. Migration guide (code → JSON)
4. Sample templates for all 6 project ideas

**Status:** Not started
**Blocking:** Requires Phase 4 working example

---

## Open Design Questions

From `wiki/JSON-Workflow-System-Design.md`, these questions need resolution during Phase 1:

### 1. Template Engine Complexity
**Question:** How much logic should templates support?

**Options:**
- Simple (Mustache): `{{variable}}` only
- Medium (Handlebars): Add `{{#if}}`, `{{#each}}`
- Complex (Jinja2): Full programming in templates

**Recommendation:** Start simple, evaluate after Phase 4

### 2. Workflow Composition
**Question:** Should workflows call sub-workflows?

**Use Case:** Reusable analysis modules

**Recommendation:** Defer to Phase 2

### 3. Real-time Updates
**Question:** Should running workflows react to JSON changes?

**Recommendation:** Not for v1

### 4. Visual Editor
**Question:** Build UI for editing workflows?

**Recommendation:** Not for v1, focus on schema quality

### 5. Cross-Language Support
**Question:** Should JSON workflows run in Python/JS?

**Recommendation:** Design schema with this in mind, implement Dart-only for v1

---

## Success Metrics

### Quantitative
- [ ] 10+ example workflows covering diverse domains
- [ ] 90%+ code reduction in sample orchestration logic
- [ ] < 10% performance overhead vs code-based workflows
- [ ] JSON schema passes validation with major validators

### Qualitative
- [ ] New contributors create workflows without understanding Dart orchestration
- [ ] Workflows are self-documenting (readable JSON)
- [ ] Extension points are clear and well-used
- [ ] Community creates workflows we didn't anticipate

---

## What's Working Well (Don't Change)

### ✅ Current Restaurant Sample
- Evolutionary algorithm works perfectly
- Pareto optimization finds diverse solutions
- UI is clear and informative
- Personalization is now correctly implemented
- Prompt editing in UI enables experimentation

### ✅ SOP Genome System
- Clean separation of evolvable parameters
- Full JSON serialization
- Generation tracking with parent IDs
- Mutation strategies work well

### ✅ Multi-Agent Collaboration Pattern
- Planner → Specialists → Synthesizer is proven
- Parallel execution of specialists is efficient
- Persona-driven personalization is effective

---

## Recommended Next Steps

### Option 1: Implement JSON Workflows (6-9 weeks)
Follow the 5-phase plan to build the JSON workflow system.

**Pros:**
- Enables rapid creation of new domains (hiring, papers, etc.)
- Makes Dartantic accessible to non-Dart developers
- Future-proofs for visual editors

**Cons:**
- Significant time investment
- Adds complexity to core framework

### Option 2: Create More Code-Based Samples (2-3 weeks)
Build one of the 6 sample projects using current code-based approach.

**Pros:**
- Validates the multi-agent pattern across domains
- Demonstrates versatility
- Faster to deliver

**Cons:**
- Each sample requires ~500 lines of orchestration code
- Pattern duplication across samples
- Still requires Dart expertise

### Option 3: Hybrid Approach (3-4 weeks)
Implement minimal JSON workflow support (Phase 1 + 2), then build one new sample.

**Pros:**
- Proves the JSON concept works
- Delivers tangible value quickly
- Validates design decisions

**Cons:**
- Partial implementation may lack polish
- Might need refactoring later

---

## Conclusion

**Current State:**
- We have a **fully functional, production-ready** evolutionary restaurant recommender
- The architecture is proven and working
- Design for JSON workflows is complete and well-documented

**Missing:**
- Implementation of the JSON workflow system has not begun
- To create new domains, you still need to write Dart orchestration code

**Decision Point:**
Should we invest 6-9 weeks to implement JSON workflows, or continue building code-based samples to demonstrate versatility?

Both are valid paths forward. The JSON system makes Dartantic more accessible; code-based samples demonstrate real-world value faster.
