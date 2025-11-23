# Self-Improving Personalized Restaurant Recommendations

A complete proof-of-concept demonstrating a **self-improving agentic RAG system** built with Dartantic AI. This application generates personalized restaurant recommendations and autonomously improves its own processes through genetic algorithms and multi-dimensional evaluation.

## 🎯 Problem Statement

Generate personalized restaurant analysis reports for different user personas that maximize decision confidence. The system learns which information styles and analysis approaches work best for different user types.

## 🏗️ Architecture

This implementation mirrors Fareed Khan's self-improving agentic RAG architecture from ["Building a Self-Improving Agentic RAG System"](https://levelup.gitconnected.com/building-a-self-improving-agentic-rag-system-part-i-architecture-principles-c1af13c43730):

### Inner Loop: Multi-Agent "Guild" Workflow
- **Planner Agent**: Coordinates analysis strategy
- **Data Analyst**: Extracts patterns and statistics from reviews
- **Service Analyst**: Evaluates service quality aspects
- **Sentiment Analyst**: Assesses overall customer satisfaction
- **Synthesizer**: Creates personalized recommendations

### Evolvable Configuration (SOP as "Genome")
```dart
class RestaurantAnalysisSOP {
  String plannerPrompt;           // How to plan analysis
  int reviewRetrieverK;           // Number of reviews to analyze
  String synthesizerPrompt;       // How to synthesize results
  String synthesizerModel;        // Which LLM to use
  bool useDataAnalyst;            // Enable/disable data analysis
  bool useServiceAnalyst;         // Enable/disable service analysis
  String personalizationLevel;    // 'low', 'medium', 'high'
}
```

### 5D Evaluation System

**LLM-Judged Dimensions:**
1. **Accuracy**: Claims supported by reviews
2. **Completeness**: Covers all important aspects
3. **Helpfulness**: Aids decision-making

**Programmatic Dimensions:**
4. **Conciseness**: Information density
5. **Data-Grounded**: Specific examples and statistics
6. **Personalization**: Matches user persona

### Outer Loop: Autonomous Evolution

```
Baseline SOP → Multi-Agent Analysis → Evaluation → Pareto Frontier
     ↑                                                      ↓
     └───────────── Selection ← Mutation ← Gene Pool ←────┘
```

**Genetic Algorithm Components:**
- **Mutation Strategies**: Parameter tweaks, structural changes, prompt enhancements
- **Selection Strategies**: Elitist, Pareto, tournament, diversity-preserving
- **Evolution Engine**: Orchestrates cycles of mutation, selection, and evaluation

## 🚀 Getting Started

### Prerequisites

- Flutter 3.38.3+ installed ([Download](https://flutter.dev/docs/get-started/install))
- Dart 3.10.1+
- **Option A**: [Ollama](https://ollama.ai) installed locally (FREE, recommended for testing)
- **Option B**: OpenAI/Anthropic/Google API key (faster, costs money)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/dartantic_ai.git
cd dartantic_ai/samples/personalized_restaurant_recs
```

2. Install dependencies:
```bash
flutter pub get
```

3. **Choose your LLM backend:**

#### Option A: Ollama (Local or Cloud via Ollama)

```bash
# Install Ollama (if not already installed)
# macOS/Linux: curl -fsSL https://ollama.ai/install.sh | sh
# Windows: Download from https://ollama.ai

# Cloud models (fast, powerful, via Ollama API):
ollama pull deepseek-v3.1:671b-cloud    # DEFAULT - best quality, 671B params
ollama pull gpt-oss:120b-cloud          # Alternative, 120B params
ollama pull qwen3-coder:480b-cloud      # Good for technical tasks

# Or local models (FREE, runs on your Mac):
ollama pull qwen2.5:7b-instruct         # Local, 7B params, good tool support
ollama pull mistral-small3.2:24b        # Local, 24B params, higher quality

# Start Ollama (usually auto-starts, but if not)
ollama serve
```

#### Option B: Cloud Provider (OpenAI/Anthropic/Google)

```bash
# Set your API key
export OPENAI_API_KEY="sk-your-key-here"
# OR
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
# OR
export GOOGLE_API_KEY="your-key-here"
```

### Running the App

#### With Default (DeepSeek v3.1 Cloud via Ollama):

```bash
flutter run -d macos
```

This uses `ollama:deepseek-v3.1:671b-cloud` - powerful 671B parameter model via Ollama.

#### Override with Different Model:

```bash
# Use local Ollama model (free, runs on your Mac)
flutter run -d macos --dart-define=MODEL=ollama:qwen2.5:7b-instruct

# Use other Ollama cloud models
flutter run -d macos --dart-define=MODEL=ollama:gpt-oss:120b-cloud
flutter run -d macos --dart-define=MODEL=ollama:qwen3-coder:480b-cloud

# Or use direct cloud providers
flutter run -d macos --dart-define=MODEL=openai:gpt-4o-mini
flutter run -d macos --dart-define=MODEL=anthropic:claude-3-5-sonnet-20241022
```

#### Run on Web (Chrome):

```bash
flutter run -d chrome
# Or with model override:
flutter run -d chrome --dart-define=MODEL=ollama:qwen2.5:7b-instruct
```

#### Other platforms:
```bash
flutter run -d linux    # Linux desktop
flutter run -d windows  # Windows desktop
```

## 📊 Using the App - The Stakeholder Journey

The app guides you through a complete journey from problem understanding to personalized recommendations:

### Step 1: Stakeholder Conversation
- **Learn why this tool exists** - understand the problem it solves
- **Enter your zip code** - specify your location
- **Select your diner profile** - foodie, budget-conscious, family-friendly, or quick lunch seeker

### Step 2: Process Visualization
- **See the workflow** - interactive Mermaid diagram showing the multi-agent process
- **Understand self-improvement** - how the system evolves better configurations
- **Set expectations** - know what to watch for in the next step

### Step 3: Evolution Journey
- **Watch real-time evolution** - see generations improve with live progress charts (using fl_chart)
- **View detailed transparency**:
  - Tap any generation to see mutations applied
  - View SOP configuration ("genome")
  - See all 6 evaluation dimensions
  - Read the actual AI-generated analysis
- **Process More** - click to run additional evolution cycles
- **Finish** - move to final report when satisfied

### Step 4: Final Report
- **Top 3 personalized recommendations** ranked by match score
- **Evidence-based analysis** for each restaurant
- **Restart** - search again with different criteria

## 🔧 Data Sources

The app automatically uses the best available data source:

1. **Real Yelp Data** (preferred): If `/tmp/yelp_dataset/` contains Yelp Academic Dataset files
2. **Synthetic Data** (fallback): Generates realistic restaurant and review data

To use real Yelp data, place these files in `/tmp/yelp_dataset/`:
- `yelp_academic_dataset_business.json`
- `yelp_academic_dataset_review.json`

## 🗂️ Project Structure

```
lib/
├── src/
│   ├── config/
│   │   └── restaurant_analysis_sop.dart      # Evolvable configuration
│   ├── data/
│   │   └── synthetic_data.dart                # Test data generator
│   ├── evaluation/
│   │   ├── evaluation_result.dart             # 5D performance vector
│   │   └── restaurant_evaluator.dart          # Multi-dimensional scoring
│   ├── evolution/
│   │   ├── evolution_engine.dart              # Orchestrates evolution
│   │   ├── mutation_strategy.dart             # Parameter/structural mutations
│   │   └── selection_strategy.dart            # Pareto/tournament/elitist
│   ├── models/
│   │   ├── restaurant.dart                    # Business data model
│   │   ├── review.dart                        # Review data model
│   │   └── user_persona.dart                  # User preference profiles
│   └── workflows/
│       └── restaurant_analysis_workflow.dart  # Multi-agent RAG pipeline
└── main.dart                                  # Flutter web UI
```

## 📈 Example Evolution Scenario

**Baseline (Gen 0):**
- Personalization: 0.30 (low)
- Helpfulness: 0.45
- Overall: 0.52

**After Diagnosis:**
> "Reports lack personalization for user context. Generic recommendations don't match foodie preferences."

**Mutation Applied:**
- `personalizationLevel: 'low' → 'high'`
- Enhanced synthesizer prompt with persona-specific instructions

**Evolved (Gen 3):**
- Personalization: 0.85 (high) ⬆️
- Helpfulness: 0.78 ⬆️
- Overall: 0.73 ⬆️

## 🔬 Using Real Yelp Data

Download the [Yelp Open Dataset](https://www.yelp.com/dataset/download) (4.9 GB) and place JSON files in `assets/data/`:

```
assets/data/
├── business.json
└── review.json
```

Update `_initializeData()` in `main.dart` to load from files instead of synthetic generation.

## 🧬 Key Concepts

### Genome Pattern
The SOP (Standard Operating Procedure) acts as a "genome" - a configuration that controls all aspects of the workflow and can be evolved over time.

### Multi-Objective Optimization
Uses Pareto frontier analysis to find non-dominated solutions across multiple dimensions. Better than single-score optimization because it preserves trade-offs (e.g., thoroughness vs. conciseness).

### LLM-as-Judge
Powerful LLMs evaluate qualitative dimensions (accuracy, helpfulness) that are hard to measure programmatically.

### Continuous Improvement
The system improves autonomously through:
1. **Evaluation**: Measure performance across dimensions
2. **Diagnosis**: Identify weaknesses (implicit in low scores)
3. **Evolution**: Generate variations through mutation
4. **Selection**: Keep best performers and Pareto-optimal solutions

## 📚 References

- [Building a Self-Improving Agentic RAG System](https://levelup.gitconnected.com/building-a-self-improving-agentic-rag-system-part-i-architecture-principles-c1af13c43730) by Fareed Khan
- [Dartantic AI Framework](https://docs.dartantic.com)
- [Yelp Open Dataset](https://www.yelp.com/dataset)

## 🤝 Contributing

This is a proof-of-concept demonstrating self-improvement capabilities. Contributions welcome to:
- Add more mutation strategies
- Implement additional selection algorithms
- Enhance evaluation dimensions
- Improve UI visualizations

## 📄 License

MIT License - see LICENSE file for details
