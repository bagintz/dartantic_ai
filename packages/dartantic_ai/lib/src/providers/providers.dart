import 'package:dartantic_interface/dartantic_interface.dart';

import 'anthropic_provider.dart';
import 'cohere_provider.dart';
import 'google_openai_provider.dart';
import 'google_provider.dart';
import 'mistral_provider.dart';
import 'ollama_openai_provider.dart';
import 'ollama_provider.dart';
import 'openai_provider.dart';
import 'openai_responses_provider.dart';
import 'openrouter_provider.dart';
import 'together_provider.dart';

export 'anthropic_provider.dart';
export 'cohere_provider.dart';
export 'google_openai_provider.dart';
export 'google_provider.dart';
export 'mistral_provider.dart';
export 'ollama_openai_provider.dart';
export 'ollama_provider.dart';
export 'openai_provider.dart';
export 'openai_responses_provider.dart';
export 'openrouter_provider.dart';
export 'together_provider.dart';

/// Providers for built-in chat and embeddings models.
class Providers {
  Providers._();

  // Private cache fields for lazy initialization
  static OpenAIProvider? _openai;
  static OpenAIResponsesProvider? _openaiResponses;
  static OpenRouterProvider? _openrouter;
  static TogetherProvider? _together;
  static MistralProvider? _mistral;
  static CohereProvider? _cohere;
  static GoogleOpenAIProvider? _googleOpenAI;
  static GoogleProvider? _google;
  static AnthropicProvider? _anthropic;
  static OllamaProvider? _ollama;
  static OllamaOpenAIProvider? _ollamaOpenAI;

  /// OpenAI provider (cloud, OpenAI API).
  static OpenAIProvider get openai => _openai ??= OpenAIProvider();

  /// OpenAI Responses provider (Responses API with reasoning metadata).
  static OpenAIResponsesProvider get openaiResponses =>
      _openaiResponses ??= OpenAIResponsesProvider();

  /// OpenRouter provider (multi-model cloud with native capability detection).
  ///
  /// OpenRouter provides access to 400+ AI models with rich capability metadata
  /// via the /api/v1/models endpoint. Capabilities are detected from:
  /// - `architecture.input_modalities`: ["text", "image", "audio", "file"]
  /// - `architecture.output_modalities`: ["text", "image"]
  /// - `supported_parameters`: ["tools", "reasoning", "structured_outputs"]
  static OpenRouterProvider get openrouter =>
      _openrouter ??= OpenRouterProvider();

  /// Together AI provider (cloud with heuristic capability detection).
  ///
  /// Together AI's API returns basic model metadata. Capabilities are detected
  /// using:
  /// - Model `type` field: "chat", "image", "audio", "embedding", etc.
  /// - Model naming patterns: "VL" suffix for vision-language models
  /// - Documented function-calling support for specific models
  ///
  /// Note: Tool support may have streaming format issues with some models.
  /// See https://docs.together.ai/docs/function-calling for supported models.
  static TogetherProvider get together => _together ??= TogetherProvider();

  /// Mistral AI provider (native API, cloud).
  static MistralProvider get mistral => _mistral ??= MistralProvider();

  /// Cohere provider (OpenAI-compatible, cloud).
  static CohereProvider get cohere => _cohere ??= CohereProvider();

  /// Gemini (OpenAI-compatible) provider (Google AI, OpenAI API).
  ///
  /// Uses Gemini-specific heuristics for capability detection since
  /// OpenAI heuristics don't work for Gemini model names.
  static GoogleOpenAIProvider get googleOpenAI =>
      _googleOpenAI ??= GoogleOpenAIProvider();

  /// Google Gemini native provider (uses Gemini API, not OpenAI-compatible).
  static GoogleProvider get google => _google ??= GoogleProvider();

  /// Anthropic provider (Claude, native API).
  static AnthropicProvider get anthropic => _anthropic ??= AnthropicProvider();

  /// Native Ollama provider (local, uses ChatOllama and /api endpoint). No API
  /// key required. Vision models like llava are available.
  static OllamaProvider get ollama => _ollama ??= OllamaProvider();

  /// OpenAI-compatible Ollama provider (local, uses /v1 endpoint). No API key
  /// required. Uses Ollama's native /api/show endpoint for capability detection.
  static OllamaOpenAIProvider get ollamaOpenAI =>
      _ollamaOpenAI ??= OllamaOpenAIProvider();

  /// Returns a list of all available providers (static fields above).
  ///
  /// Use this to iterate or display all providers in a UI.
  /// NOTE: Filters out duplicate providers by alias.
  static List<Provider> get all => providerMap.entries
      .where((e) => !e.value.aliases.contains(e.key))
      .map((e) => e.value)
      .toList();

  /// Returns all providers that have the specified model-level capabilities.
  /// NOTE: Upstream removed `ProviderCaps` and capability support is now
  /// model-specific (per-model `ModelCaps`). For now this helper returns
  /// all providers; callers should instead query `listModels()` for
  /// model-level capability discovery.
  static List<Provider> allWith(Set<ModelCaps> caps) => all;

  static final _providerMap = <String, Provider>{};

  /// Returns all intrinsic providers (lazily evaluated).
  static List<Provider> get _intrinsicProviders => <Provider>[
    openai,
    openaiResponses,
    openrouter,
    together,
    mistral,
    cohere,
    google,
    googleOpenAI,
    anthropic,
    ollama,
    ollamaOpenAI,
  ];

  /// Returns a map of all providers by name or alias.
  /// Extensible at runtime by adding to your own [Provider] subclass.
  static Map<String, Provider> get providerMap {
    if (_providerMap.isEmpty) {
      for (final provider in _intrinsicProviders) {
        final providerName = provider.name.toLowerCase();
        assert(
          !_providerMap.containsKey(providerName),
          'Provider $providerName is already in use',
        );
        _providerMap[providerName] = provider;
        for (final alias in provider.aliases) {
          final providerAlias = alias.toLowerCase();
          assert(
            !_providerMap.containsKey(providerAlias),
            'Provider alias $providerAlias is already in use',
          );
          _providerMap[providerAlias] = provider;
        }
      }
    }

    return _providerMap;
  }

  /// Looks up a provider by name or alias (case-insensitive). Throws if not
  /// found.
  static Provider get(String name) {
    final providerName = name.toLowerCase();
    final provider = providerMap[providerName];
    if (provider == null) throw Exception('Provider $providerName not found');
    return provider;
  }
}
