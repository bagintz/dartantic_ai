# Cactus Main Branch Migration Guide

**Status**: Ready to implement (waiting for stable WiFi)  
**Date**: October 19, 2025  
**Estimated Time**: ~4 hours

## Decision: Migrate to Main Branch

We're migrating dartantic_cactus from Cactus legacy (0.2.7) to main branch (0.3.1+) for these reasons:

- ✅ **Active maintenance**: Main branch last updated Oct 19, 2025
- ✅ **Better architecture**: Service-based design, improved APIs
- ✅ **Future-proof**: Official development branch
- ❌ **Breaking change**: Vision and TTS support removed (temporary loss)

### What Changes

| Feature | Legacy (0.2.7) | Main (0.3.1) | Impact |
|---------|----------------|--------------|--------|
| Text Generation | ✅ CactusLM | ✅ CactusLM (improved) | ✅ Better API |
| Vision/Multimodal | ✅ CactusVLM | ❌ Removed | ⚠️ Feature loss |
| TTS | ⚠️ CactusTTS (broken) | ❌ Removed | ✅ No loss |
| Embeddings | ✅ Via LM | ✅ Via LM | ✅ Works |
| Installation | pub.dev | GitHub source | ⚠️ Manual |

## Implementation Checklist

### Phase 1: Remove Unsupported Features (45 min)

- [ ] **Remove Vision/VLM Support**
  - Delete `CactusVLM` references from `cactus_chat_model.dart`
  - Remove vision fields from `cactus_chat_options.dart` (mmprojUrl, mmprojFilename, supportVision)
  - Remove `ProviderCapabilities.vision` from `cactus_provider.dart`
  - Remove `_hasVisualContent()` method and image handling

- [ ] **Delete TTS Support**
  - Delete entire file: `lib/src/cactus_tts_model.dart`
  - Remove TTS from `cactus_provider.dart` capabilities
  - Remove `createTTSModel()` method

### Phase 2: Update API Calls (90 min)

- [ ] **Refactor CactusChatModel Initialization**
  ```dart
  // OLD API
  await _lm!.download(modelUrl: url, onProgress: callback);
  await _lm!.init(contextSize: size, gpuLayers: layers);
  
  // NEW API  
  await _lm!.downloadModel(model: 'qwen3-0.6', downloadProcessCallback: callback);
  await _lm!.initializeModel(params: CactusInitParams(model: 'qwen3-0.6', contextSize: size));
  ```

- [ ] **Update Completion Calls**
  ```dart
  // OLD: _lm!.completion(messages, maxTokens: n)
  // NEW: _lm!.generateCompletion(messages: messages, params: CactusCompletionParams(...))
  ```

- [ ] **Update CactusEmbeddingsModel**
  - Change `embedding()` → `generateEmbedding(text:, modelName:)`
  - Extract embeddings from `CactusEmbeddingResult.embeddings`

### Phase 3: Update Configuration (30 min)

- [ ] **Refactor CactusChatModelOptions**
  - Change `modelUrl` (String) → `modelSlug` (String)
  - Remove vision-related fields
  - Remove legacy fields (gpuLayers, threads, chatTemplate)
  - Update default values

- [ ] **Update examples**
  ```dart
  // OLD: modelUrl: 'https://huggingface.co/...'
  // NEW: modelSlug: 'qwen3-0.6'
  ```

### Phase 4: Testing & Documentation (60 min)

- [ ] **Run Tests**
  ```bash
  flutter pub get
  dart analyze
  flutter test
  ```

- [ ] **Update README.md**
  - Document GitHub installation method
  - Remove vision/TTS examples
  - Add migration notes for existing users
  - Update API examples

- [ ] **Update CHANGELOG.md**
  - Document breaking changes
  - Note feature removals
  - Bump version to 0.2.0 (breaking changes)

## Breaking Changes for Users

### Installation Change
```yaml
# Users must update their pubspec.yaml:
dependencies:
  dartantic_cactus:
    git:
      url: https://github.com/csells/dartantic_ai.git
      path: packages/dartantic_cactus
```

### Vision Support Removed
```dart
// OLD - This no longer works
CactusChatModelOptions(
  modelUrl: '...',
  mmprojUrl: '...',  // ❌ Removed
  supportVision: true,  // ❌ Removed
);

// Workaround: Use Firebase AI or another provider for vision
```

### Model Configuration Changed
```dart
// OLD
CactusChatModelOptions(
  modelUrl: 'https://huggingface.co/model.gguf',
)

// NEW
CactusChatModelOptions(
  modelSlug: 'qwen3-0.6',  // Use catalog slug
)
```

## File Changes Summary

### Files to Modify
- ✅ `pubspec.yaml` - Already updated to GitHub source
- `lib/src/cactus_chat_model.dart` - Main refactor
- `lib/src/cactus_embeddings_model.dart` - API updates
- `lib/src/cactus_provider.dart` - Remove capabilities
- `lib/src/cactus_chat_options.dart` - New fields
- `README.md` - Full documentation update
- `CHANGELOG.md` - Document breaking changes

### Files to Delete
- `lib/src/cactus_tts_model.dart`

### Files Created
- This guide (MAIN_BRANCH_MIGRATION.md)

## Next Steps

1. **Get stable WiFi** - Run `flutter pub get` successfully
2. **Follow checklist** - Implement changes in order
3. **Test thoroughly** - Ensure no regressions
4. **Update docs** - Keep users informed
5. **Commit changes** - Clean git history

## Rollback Plan

If migration fails, revert `pubspec.yaml`:
```yaml
dependencies:
  cactus: ^0.2.7  # Back to pub.dev version
```

Then run `flutter pub get` and everything reverts to working state.

## Questions/Issues

- **CactusAgent**: Need to verify if it still exists and works the same way
- **Model catalog**: How to discover available model slugs?
- **Vision roadmap**: Asked in Discord, awaiting response

---

**Ready to execute when WiFi is available!** 🚀
