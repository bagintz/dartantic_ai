# Dartantic AI Upstream Update Plan

**Date**: December 20, 2025  
**Branch**: `dartantic_rag_flow`  
**Upstream**: csells/dartantic_ai (main)  
**Fork**: bagintz/dartantic_ai

## Executive Summary

There have been **significant updates** (596 files changed) to the upstream csells/dartantic_ai repository. This plan outlines how to safely merge these changes into our `dartantic_rag_flow` branch while preserving our custom work.

## Major Changes in Upstream (v2.0+)

### ✅ New Features Added
1. **CLI Tool** (`dartantic_cli`) - Complete CLI interface with 72+ example scripts
2. **Media Generation** - New media generation capabilities for images/audio/video
3. **Thinking Mode** - Enhanced thinking/reasoning features
4. **Server-Side Tools Expansion** - Anthropic & Google server-side tool support

### ⚠️ Breaking Changes - Providers
**Removed Providers** (now deprecated/consolidated):
- `openrouter_provider.dart` (255 lines removed)
- `together_provider.dart` (279 lines removed)  
- `google_openai_provider.dart` (170 lines removed)
- `ollama_openai_provider.dart` (215 lines removed)

**Note**: These providers were likely consolidated into the base OpenAI-compatible provider.

### ⚠️ Breaking Changes - Packages Removed
The following packages were **completely removed** from upstream:
- `dartantic_diagnosis` (478+ lines)
- `dartantic_evaluation` (268+ lines)
- `dartantic_evolution` (387+ lines)
- `dartantic_optimization` (486+ lines)
- `dartantic_objectbox` (full ObjectBox integration)
- `dartantic_objectbox_flutter`
- `dartantic_sqlite` (SQLite data store)
- `dartantic_sqlite_flutter`
- `dartantic_workflows` (graph/sequential workflows)
- `personalized_restaurant_recs` sample

### 📝 Interface Changes
- `dartantic_interface` updated with media generation types
- Removed: `model_caps.dart`, `provider_caps.dart`, data store interfaces
- Added: Media generation model interfaces

### 🗑️ Documentation/Specs Removed
- All `ai_notes/` content removed
- `landing-page/` removed
- Migration plans and architecture docs removed

## Our Custom Changes (dartantic_rag_flow branch)

### ✨ Features We Added (Must Preserve)
1. **Model Capabilities System** (`MODEL_CAPS_IMPLEMENTATION.md`)
   - `fetchModelCaps()` for all major providers (Anthropic, Google, OpenAI, Cohere, Mistral, Ollama)
   - Test files: `*_model_caps_test.dart` (8 test files, ~2500 lines)

2. **Dedicated Provider Classes**
   - `OpenRouterProvider` 
   - `TogetherProvider`
   - `GoogleOpenAIProvider`
   - `OllamaOpenAIProvider`
   - **CONFLICT**: These were removed upstream!

3. **Packages We Developed** (Need to preserve & update)
   - `dartantic_diagnosis` - Performance analysis and diagnostics
   - `dartantic_evaluation` - Multi-dimensional evaluation system
   - `dartantic_evolution` - Genetic algorithm optimization
   - `dartantic_optimization` - Autonomous self-improvement
   - `dartantic_objectbox` - ObjectBox data store
   - `dartantic_objectbox_flutter` - Flutter ObjectBox integration
   - `dartantic_sqlite` - SQLite data store
   - `dartantic_sqlite_flutter` - Flutter SQLite integration
   - `dartantic_workflows` - Graph-based workflow engine
   - `personalized_restaurant_recs` - Full sample application

4. **Documentation We Created**
   - JSON Workflow System Design & Status (`wiki/JSON-Workflow-*.md`)
   - AI Notes and implementation prompts
   - Data stores implementation guide
   - Orchestrator proposals

5. **Interface Extensions**
   - Added `model_caps.dart` to dartantic_interface
   - Added data store interfaces (DatabaseStore, VectorStore)

## Conflicts Analysis

### 🔴 Critical Conflicts (Direct Overlap)

#### 1. Provider Files
**Files with conflicting changes:**
- `anthropic_provider.dart` - Both modified
- `cohere_provider.dart` - Both modified (we added 283 lines)
- `google_provider.dart` - Both modified (we added 116 lines)
- `mistral_provider.dart` - Both modified (we added 170 lines)
- `ollama_provider.dart` - Both modified (we added 59 lines)
- `openai_provider_base.dart` - Both modified (we added 166 lines)
- `providers.dart` - We added 102 lines, they removed 157

#### 2. Removed vs. Our Additions
**We added these, but upstream removed them:**
- `openrouter_provider.dart` - We added 255 lines, upstream removed
- `together_provider.dart` - We added 279 lines, upstream removed
- `google_openai_provider.dart` - We added 170 lines, upstream removed
- `ollama_openai_provider.dart` - We added 215 lines, upstream removed

#### 3. Interface Conflicts
- `dartantic_interface/lib/src/model/model_info.dart` - Modified by both
- `dartantic_interface/lib/src/provider/provider.dart` - We added 34 lines

### 🟡 Moderate Conflicts (Package Existence)

All these packages exist in our branch but were removed upstream:
- `dartantic_diagnosis/`
- `dartantic_evaluation/`
- `dartantic_evolution/`
- `dartantic_optimization/`
- `dartantic_objectbox/`
- `dartantic_objectbox_flutter/`
- `dartantic_sqlite/`
- `dartantic_sqlite_flutter/`
- `dartantic_workflows/`
- `samples/personalized_restaurant_recs/`

### 🟢 Low Conflicts (Documentation)

- AI notes and planning docs (we have, upstream removed)
- Wiki pages (some overlap in modifications)

## Recommended Strategy

### Phase 1: Backup & Preparation ✅
```bash
# Create backup branch
git checkout dartantic_rag_flow
git branch dartantic_rag_flow_backup_2025-12-20
git push origin dartantic_rag_flow_backup_2025-12-20

# Ensure we have latest upstream
git fetch upstream
```

### Phase 2: Analysis & Decision Making

#### Decision 1: Provider Architecture
**Options:**
a) **Keep our dedicated providers** (OpenRouter, Together, etc.) as separate classes
b) **Adopt upstream's consolidated approach** and migrate our model caps to it
c) **Hybrid**: Keep separate providers but refactor to match new patterns

**Recommendation**: Option C (Hybrid)
- Upstream likely consolidated for maintainability
- Our model caps system is valuable
- Need to understand their new architecture first

#### Decision 2: Removed Packages
**Options:**
a) **Keep all our packages** as separate modules
b) **Accept upstream removal** and archive our work
c) **Selective preservation** - keep most valuable packages

**Recommendation**: Option A (Keep all packages)
- These represent significant value and functionality
- They're separate packages, not directly conflicting
- May need to update dependencies to work with new core

#### Decision 3: Interface Changes
**Options:**
a) Keep our extensions (model_caps, data stores)
b) Remove our extensions and use upstream only
c) Propose our extensions back to upstream

**Recommendation**: Option A + C
- Our capabilities system is valuable
- Could be contributed back after testing

### Phase 3: Merge Strategy

#### Approach: Careful Manual Merge

```bash
# Start merge
git checkout dartantic_rag_flow
git merge upstream/main --no-commit --no-ff

# This will create conflicts - DON'T PANIC!
```

#### Expected Conflict Resolution Plan

**Step 1: Core Package Conflicts (`packages/dartantic_ai/`)**

For provider files with conflicts:
1. Accept upstream changes as base
2. Re-apply our `fetchModelCaps()` implementations
3. Update our code to match new patterns/APIs
4. Keep our model caps tests, update to new API

**Step 2: Interface Conflicts (`dartantic_interface/`)**

1. Accept upstream media generation additions
2. Keep our model_caps.dart additions
3. Keep our data store interfaces (they don't conflict)
4. Update model_info.dart to merge both changes

**Step 3: Removed Providers**

For providers we added that upstream removed:
1. Keep them in our fork initially
2. Test if they still work with new core
3. Consider refactoring to use new OpenAI-compat base
4. Document as "community extensions"

**Step 4: Packages We Developed**

1. Keep all packages (no direct conflicts)
2. Update their `pubspec.yaml` dependencies
3. Update imports if API changed
4. Run tests and fix breakages

**Step 5: Documentation**

1. Keep our JSON Workflow docs
2. Keep our AI notes (valuable history)
3. Accept upstream's new CLI docs
4. Merge wiki changes carefully

### Phase 4: Testing & Validation

```bash
# After resolving conflicts and committing merge

# 1. Get all dependencies
dart pub get

# 2. Run all package tests
cd packages/dartantic_ai && dart test
cd ../dartantic_interface && dart test
cd ../dartantic_diagnosis && dart test
cd ../dartantic_evaluation && dart test
cd ../dartantic_evolution && dart test
cd ../dartantic_optimization && dart test
cd ../dartantic_workflows && dart test

# 3. Test our custom providers
dart test test/openrouter_model_caps_test.dart
dart test test/together_model_caps_test.dart

# 4. Run integration tests
dart test test/system_integration_test.dart

# 5. Test samples
cd samples/chatarang && dart run bin/chatarang.dart --help
```

### Phase 5: API Migration

After merge, we'll need to update code that uses:
1. **Changed APIs** in providers
2. **New streaming patterns** (if any)
3. **Media generation features** (understand & adopt)
4. **New thinking/reasoning APIs**
5. **Updated model string parsing**

### Phase 6: Documentation Update

Update our docs to reflect:
1. What we preserved vs. what we adopted
2. Our custom extensions (model caps, extra providers)
3. Our additional packages
4. Migration guide for our users

## Risk Assessment

### 🔴 High Risk Areas
- Provider refactoring (will require significant code updates)
- Test compatibility (may need extensive test updates)
- API breaking changes in interfaces

### 🟡 Medium Risk Areas  
- Package dependency version mismatches
- Documentation conflicts
- Example code updates

### 🟢 Low Risk Areas
- Our separate packages (minimal coupling to core)
- Documentation additions
- Test additions (mostly new files)

## Success Criteria

✅ All tests passing after merge
✅ All our custom packages working with new core
✅ Model caps system functional
✅ Our additional providers working (or migrated)
✅ No regression in existing functionality
✅ Successfully using new features (CLI, media gen, thinking)

## Rollback Plan

If merge fails catastrophically:
```bash
git merge --abort  # If mid-merge
# OR
git reset --hard dartantic_rag_flow_backup_2025-12-20  # If committed
git push origin dartantic_rag_flow --force-with-lease  # After confirming with team
```

## Timeline Estimate

- **Phase 1** (Backup): 5 minutes ✅
- **Phase 2** (Analysis): 30 minutes - 1 hour
- **Phase 3** (Merge): 2-4 hours (conflict resolution)
- **Phase 4** (Testing): 1-2 hours
- **Phase 5** (API Migration): 2-3 hours
- **Phase 6** (Documentation): 1 hour

**Total**: 6-11 hours of focused work

## Next Steps

1. ✅ Review this plan
2. ✅ Get team approval on strategy decisions
3. ⏳ Create backup branch
4. ⏳ Begin Phase 3 (Merge)
5. ⏳ Resolve conflicts systematically
6. ⏳ Test thoroughly
7. ⏳ Document changes
8. ⏳ Push updated branch

## Questions to Answer Before Starting

1. **Do we want to keep all our custom packages?** 
   - Recommendation: Yes, they provide value
   
2. **Should we try to contribute model caps back to upstream?**
   - Recommendation: Yes, after stabilization
   
3. **How do we handle removed providers?**
   - Recommendation: Keep initially, evaluate after testing
   
4. **Do we adopt upstream's provider architecture?**
   - Recommendation: Yes, but preserve our enhancements

5. **Should we use the new CLI tool?**
   - Recommendation: Yes, evaluate and integrate

## Notes

- Upstream is at v2.0+, significant architectural changes
- Our fork has valuable extensions worth preserving
- Merge will require careful conflict resolution
- Testing is critical - allocate sufficient time
- Consider this a major version upgrade for our fork

---

**Created**: December 20, 2025  
**Author**: AI Assistant  
**Status**: Ready for Review
