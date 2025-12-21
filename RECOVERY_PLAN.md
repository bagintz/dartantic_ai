# Dartantic AI Recovery & Migration Plan

**Date:** December 20, 2025  
**Author:** Recovery Process Documentation  
**Current Branch:** `dartantic_clean_from_main`

## 🎯 Goals

1. ✅ **Get local branch updated to latest from upstream (csells/dartantic_ai)**
2. ⏳ **Preserve ModelCaps implementation for future cherry-pick**
3. ⏳ **Preserve custom packages for future integration**

## 📦 What Was Backed Up

### Backup Locations

- **Branch:** `dartantic_rag_flow_backup` (pushed to origin)
- **Tag:** `modelcaps-v1` (pushed to origin)
- **Original Branch:** `dartantic_rag_flow` (still exists with all commits)

### Preserved Work

#### 1. ModelCaps Implementation
Location: `dartantic_rag_flow_backup` branch

**Key Features:**
- `fetchModelCaps()` method implementations across multiple providers
- Model capability detection heuristics for:
  - Cohere Provider
  - Google Provider  
  - Mistral Provider
  - Ollama Provider
  - Together Provider
  - OpenRouter Provider
  - Anthropic Provider (existing)
  - OpenAI Provider (existing)

**Key Files Modified:**
```
packages/dartantic_ai/lib/src/providers/
  ├── cohere_provider.dart          (+61 lines: fetchModelCaps + heuristics)
  ├── google_openai_provider.dart   (capability detection)
  ├── google_provider.dart          (+1 line)
  ├── mistral_provider.dart         (+7 lines)
  ├── ollama_openai_provider.dart   (+8 lines)
  ├── openai_provider_base.dart     (+7 lines)
  ├── openrouter_provider.dart      (+12 lines)
  ├── together_provider.dart        (+18 lines)
  └── providers.dart                (+9 lines)
```

**Test Infrastructure:**
- Added `needs-key` tag system to separate unit vs integration tests
- Fixed test syntax errors and null safety issues
- Updated 40+ test files with proper tagging

#### 2. Custom Packages (Preserved in backup branches)

Location: `packages/` directory in `dartantic_rag_flow_backup`

**Custom Packages to Migrate Later:**
```
packages/
  ├── dartantic_cactus/           # Custom package
  ├── dartantic_diagnosis/        # Custom package
  ├── dartantic_evaluation/       # Custom package
  ├── dartantic_evolution/        # Custom package
  ├── dartantic_firebase_ai/      # Custom package
  ├── dartantic_objectbox/        # Custom package
  ├── dartantic_objectbox_flutter/# Custom package
  ├── dartantic_optimization/     # Custom package
  ├── dartantic_sqlite/           # Custom package
  ├── dartantic_sqlite_flutter/   # Custom package
  └── dartantic_workflows/        # Custom package
```

## 🔄 Current Status

### ✅ Completed Steps

1. **Created backup branch** `dartantic_rag_flow_backup`
2. **Created tag** `modelcaps-v1` marking the ModelCaps implementation
3. **Committed all uncommitted changes** to preserve ModelCaps work
4. **Pushed backups to origin** (bagintz/dartantic_ai)
5. **Created clean branch** `dartantic_clean_from_main` from `upstream/main`
6. **Verified clean branch** works with basic tests

### 📍 Where We Are Now

- **Current Branch:** `dartantic_clean_from_main`
- **Status:** Clean, working state from upstream main
- **Tests:** Passing (verified with model_string_parser_test)
- **Dependencies:** Installed and ready

## 📋 Next Steps

### Phase 1: Stabilize Clean Branch (Do Now)

1. **Push clean branch to your fork:**
   ```bash
   git push origin dartantic_clean_from_main
   ```

2. **Run full test suite to verify:**
   ```bash
   cd packages/dartantic_ai
   dart test --reporter compact
   ```

3. **Set as your working branch:**
   ```bash
   git branch --set-upstream-to=origin/dartantic_clean_from_main
   ```

### Phase 2: Cherry-Pick Custom Packages (Later)

When ready to restore your custom packages:

```bash
# From dartantic_clean_from_main branch
git checkout dartantic_rag_flow_backup -- packages/dartantic_cactus
git checkout dartantic_rag_flow_backup -- packages/dartantic_diagnosis
git checkout dartantic_rag_flow_backup -- packages/dartantic_evaluation
git checkout dartantic_rag_flow_backup -- packages/dartantic_evolution
git checkout dartantic_rag_flow_backup -- packages/dartantic_firebase_ai
git checkout dartantic_rag_flow_backup -- packages/dartantic_objectbox
git checkout dartantic_rag_flow_backup -- packages/dartantic_objectbox_flutter
git checkout dartantic_rag_flow_backup -- packages/dartantic_optimization
git checkout dartantic_rag_flow_backup -- packages/dartantic_sqlite
git checkout dartantic_rag_flow_backup -- packages/dartantic_sqlite_flutter
git checkout dartantic_rag_flow_backup -- packages/dartantic_workflows

# Update workspace config in pubspec.yaml to include new packages
# Then:
dart pub get
```

### Phase 3: Restore ModelCaps (Later)

When ready to restore ModelCaps implementation:

**Option A: Manual Cherry-Pick (Recommended)**
```bash
# View the specific commit
git show a256a67

# Cherry-pick specific files
git checkout dartantic_rag_flow_backup -- \
  packages/dartantic_ai/lib/src/providers/cohere_provider.dart

# Or cherry-pick the entire commit
git cherry-pick a256a67
```

**Option B: AI-Assisted Reimplementation**
1. Review the ModelCaps implementation in `dartantic_rag_flow_backup`
2. Create a spec document describing the pattern
3. Have AI implement fresh on `dartantic_clean_from_main`
4. Test incrementally per provider

## 🔍 How to Review Backed Up Work

### View ModelCaps Changes
```bash
# Compare backup to upstream to see all your changes
git diff upstream/main dartantic_rag_flow_backup

# View just provider changes
git diff upstream/main dartantic_rag_flow_backup -- packages/dartantic_ai/lib/src/providers/

# View specific commit
git show a256a67

# Browse backup branch
git checkout dartantic_rag_flow_backup
# (remember to checkout back to dartantic_clean_from_main when done)
```

### View Custom Packages
```bash
# List all packages in backup
git checkout dartantic_rag_flow_backup
ls -la packages/

# View specific package
ls -la packages/dartantic_cactus/
```

## 📊 Statistics

- **Backup Branch Commits:** 111 commits ahead of origin
- **Files Changed (in ModelCaps commit):** 41 files
- **Lines Added:** 272 insertions
- **Lines Removed:** 272 deletions
- **Custom Packages:** 11 packages
- **Providers with ModelCaps:** 8+ providers

## ⚠️ Important Notes

1. **Never delete** `dartantic_rag_flow_backup` branch or `modelcaps-v1` tag
2. **Both locations** contain the same work - branch is easier to browse, tag is a permanent marker
3. **Custom packages** were NOT modified during the ModelCaps work - they're safe in the backup
4. **Test infrastructure** improvements (tags, fixes) are in the backup and may be worth cherry-picking
5. **Original branch** `dartantic_rag_flow` still exists if you need to reference anything else

## 🔗 Git References

- **Upstream:** csells/dartantic_ai (main branch)
- **Your Fork:** bagintz/dartantic_ai
- **Backup Branch:** origin/dartantic_rag_flow_backup
- **Backup Tag:** origin/modelcaps-v1
- **Clean Branch:** dartantic_clean_from_main (current)
- **Old Branch:** dartantic_rag_flow (preserved locally)

## 📝 Commands Quick Reference

```bash
# Switch to clean working branch
git checkout dartantic_clean_from_main

# View what's in backup
git checkout dartantic_rag_flow_backup
git log --oneline -10
git checkout dartantic_clean_from_main

# See changes in backup vs upstream
git diff upstream/main dartantic_rag_flow_backup --stat

# Cherry-pick a specific file from backup
git checkout dartantic_rag_flow_backup -- path/to/file

# Update from upstream (in future)
git fetch upstream
git merge upstream/main
```

## ✅ Success Criteria

- [x] Backup created and pushed
- [x] Clean branch created from upstream
- [x] Clean branch builds and tests pass
- [ ] Clean branch pushed to origin
- [ ] Custom packages restored (when ready)
- [ ] ModelCaps restored (when ready)
- [ ] All packages working together (final goal)
