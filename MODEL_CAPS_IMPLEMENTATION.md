# Model Capabilities Implementation

## Overview
This document tracks the implementation of per-model capability reporting using the `ModelCaps` enum across all providers in dartantic_ai.

## ✅ Completed Work

### 1. Core Infrastructure
- **`ModelCaps` enum** - Defined in `packages/dartantic_interface/lib/src/model/model_caps.dart`
  - Capabilities: `chat`, `chatVision`, `multiToolCalls`, `typedOutput`, `typedOutputWithTools`, `thinking`, `embeddings`, `audio`, `image`, `tts`, `countTokens`

### 2. Provider Interface Updates
- **Location**: `packages/dartantic_interface/lib/src/provider/provider.dart`
- Added centralized caching mechanism with static `_modelCapsCache` map
- Added `getModelCaps(String modelName, [Map<String, dynamic>? modelData])` with built-in caching
- Added abstract `fetchModelCaps(String modelName, [Map<String, dynamic>? modelData])` for providers to implement
- Cache key format: `"providerName:modelName"`

### 3. Ollama Provider Implementation
- **Location**: `packages/dartantic_ai/lib/src/providers/ollama_provider.dart`
- Fully implemented `fetchModelCaps()` method
- Calls `/api/show` endpoint to retrieve model details
- Maps Ollama API capabilities to `ModelCaps`:
  - `completion`/`insert` → `ModelCaps.chat`
  - `vision` → `ModelCaps.chatVision`
  - `tools` → `ModelCaps.multiToolCalls`, `ModelCaps.typedOutput`, `ModelCaps.typedOutputWithTools`
  - `thinking` → `ModelCaps.thinking`
  - `embedding`/`embeddings` → `ModelCaps.embeddings`
- Integrated with `listModels()` to populate `ModelInfo.caps`

### 4. Other Providers
All providers updated with stub implementations returning `null`:
- `openai_provider_base.dart`
- `google_provider.dart`
- `anthropic_provider.dart`
- `mistral_provider.dart`
- `cohere_provider.dart`
- `example/bin/custom_provider.dart`

### 5. Test Updates
All test files updated to use `fetchModelCaps()`:
- `test/empty_after_tools_guard_test.dart`
- `test/system_integration_test.dart`
- `test/agent_config_test.dart`

## ⚠️ Minor Cleanup Needed

### Debug Statement
- **File**: `packages/dartantic_ai/lib/src/providers/ollama_provider.dart:98`
- **Issue**: Contains `print("modelData: $modelData");`
- **Action**: Remove or convert to logger statement

## 🔮 Future Enhancements

### 1. Provider-Specific Implementations
Consider implementing `fetchModelCaps()` for other providers if their APIs expose capability information:
- **OpenAI**: Could parse model IDs (e.g., `gpt-4-vision-preview` → `chatVision`)
- **Anthropic**: Could detect Claude models with vision/tools capabilities
- **Google**: Gemini models with multi-modal capabilities
- **Mistral**: Models with tool calling support

### 2. Cache Management
- Add TTL (time-to-live) for cache entries
- Add cache clear/invalidation mechanism
- Consider persisting cache across application restarts

### 3. Testing
- Add unit tests for Ollama `fetchModelCaps()` implementation
- Add tests for cache behavior
- Mock Ollama API responses for consistent testing

### 4. Documentation
- Add examples showing how to query model capabilities
- Document the caching behavior in user-facing docs
- Add migration guide for custom provider implementations

## Architecture Notes

### How It Works
1. When `listModels()` is called, it invokes `getModelCaps(modelName, modelData)` for each model
2. `getModelCaps()` checks the cache using key `"providerName:modelName"`
3. If not cached, it calls the provider's `fetchModelCaps()` implementation
4. The result is cached and returned
5. Subsequent calls for the same model return the cached value

### Design Decisions
- **Caching in Provider interface**: Centralized to avoid duplication across providers
- **Separate `fetchModelCaps()` method**: Allows providers to focus on fetching logic without worrying about caching
- **Nullable return**: Providers can return `null` if they cannot determine capabilities
- **Optional modelData parameter**: Allows providers to extract capabilities from listing API data without additional API calls

## Tested With
- Ollama model: `all-minilm:22m` - confirmed returns `[ModelCaps.embeddings]`

## Branch
- **Branch**: `model-caps`
- **Base**: `main`
