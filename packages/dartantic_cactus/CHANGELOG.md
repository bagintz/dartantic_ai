# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Main Branch Migration

### Changed (2025-10-25)
- Updated Cactus SDK to commit `310992e` (Oct 24, 2025): thread locks, parameter changes, and internal reorg
- Removed deprecated `model` parameter from `CactusCompletionParams` usage in chat model
- Aligned default `stopSequences` with Cactus SDK defaults: `<|im_end|>`, `<end_of_turn>`

### ⚠️ Breaking Changes
- **REMOVED**: Vision/multimodal support (VLM) - not available in Cactus main branch
- **REMOVED**: TTS (text-to-speech) support - not available in Cactus main branch
- **CHANGED**: Model configuration now uses `modelSlug` instead of `modelUrl`
- **CHANGED**: Installation method now requires GitHub source (not on pub.dev)
- **CHANGED**: API updates to match Cactus main branch (0.3.1+)

### Changed
- Updated to Cactus main branch from GitHub
- Refactored initialization: `download()` → `downloadModel()`, `init()` → `initializeModel()`
- Refactored completion: `completion()` → `generateCompletion()`
- Model catalog system replaces direct URL downloads
- Simplified configuration options (removed legacy parameters)

### Removed
- `CactusTTSModel` class and TTS capabilities
- Vision-related options: `mmprojUrl`, `mmprojFilename`, `supportVision`
- Legacy initialization parameters: `gpuLayers`, `threads`, `chatTemplate`

### Migration
- See [MAIN_BRANCH_MIGRATION.md](MAIN_BRANCH_MIGRATION.md) for detailed migration guide
- Users requiring vision should use `dartantic_firebase_ai` or other providers

## [0.1.0] - Initial Development

### Added
- Initial implementation based on Cactus legacy branch (0.2.7)
- Support for on-device GGUF model execution
- Chat model implementation with streaming support
- Embeddings model for text similarity
- Basic provider infrastructure