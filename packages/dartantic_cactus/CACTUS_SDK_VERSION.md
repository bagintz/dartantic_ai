# Cactus SDK Version Tracking

This document tracks which version of the Cactus Flutter SDK we are using and any notable updates.

## Current Version

**Repository:** https://github.com/cactus-compute/cactus-flutter  
**Branch:** main  
**Commit:** `6c1c974d04de8d4eb046ffdd9b86c4d8792206af`  
**Date:** October 22, 2025  
**Version:** 0.3.1 (Cactus main branch API)

### Latest Update (October 22, 2025)

Updated from commit `0be2f8a` to `6c1c974` (+7 commits). New features included:

1. **Tool filtering** - Enhanced tool selection and filtering capabilities
2. **Updated default CactusCompletionParams** - Improved default parameter handling
3. **RAG with vector search** - Built-in vector search for RAG workflows (merged from rag branch)
4. **Model download improvements** - Easier model download process
5. **Live model fetching** - Dynamic model availability checking

All 69 tests passing after update. ✅

## Migration Notes

We migrated from the Cactus legacy API to the main branch (0.3.1) on October 19, 2025. This migration included:

- Updated from legacy `CactusChat` API to new `CactusLM` API
- Changed model initialization to use `CactusInitParams`
- Updated completion methods to use `CactusCompletionParams`
- Migrated to `generateCompletion()` and `generateCompletionStream()`
- Removed vision/TTS capabilities (not yet available in main branch)
- Updated tool calling to use built-in `tools` parameter in `CactusCompletionParams`

## Available Updates

**All updates applied! ✅**

Currently on the latest main branch commit as of October 22, 2025.

## Branches to Watch

### Active Development Branches

1. **memory** branch
   - Latest: `45554d7` - "Add llm memory" (Oct 17, 2025)
   - Status: 1 commit ahead, 7 commits behind main
   - Feature: LLM conversation memory support
   - Could be useful for multi-turn conversation context

2. **long_context** branch  
   - Latest: `156ca09` - "Sync binaries" (Oct 20, 2025)
   - Status: 1 commit ahead, 7 commits behind main
   - Feature: Long context window support
   - Could enable processing longer documents/conversations

### Merged Branches

- **rag** - Merged into main (Oct 21, 2025) - Now available in current version!

## Upcoming Features (from Cactus team)

Based on conversation with Roman Shemet (Cactus maintainer) on October 22, 2025:

- **TTS Support:** Never fully supported in legacy, will be added to new engine "in the coming months"
- **VLM (Vision) Support:** Coming to the new engine "this week" (week of Oct 20, 2025)
- Migration from legacy to new engine is in progress

## Update Process

To update to the latest Cactus SDK:

1. Update the `ref` in `pubspec.yaml` to the desired commit hash
2. Run `flutter pub get` or `flutter pub upgrade`
3. Check for breaking changes in the Cactus repository
4. Update our implementation if needed
5. Run tests to ensure compatibility
6. Update this document with the new commit hash and date

## Compatibility Notes

- Requires Dart SDK ^3.8.0
- Compatible with Flutter
- Main branch (0.3.1+) has different API than legacy branch
- Tool calling uses `CactusCompletionParams.tools` parameter
- Vision/TTS features not yet available in main branch

## Resources

- Cactus Flutter Repository: https://github.com/cactus-compute/cactus-flutter
- Cactus Documentation: (check repository README)
- Cactus Community Showcase: (may be applicable for dartantic_cactus provider)
