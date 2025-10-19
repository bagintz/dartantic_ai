# Git Commit Guide for Cactus Main Branch Migration Prep

## Summary
This commit prepares dartantic_cactus for migration to Cactus main branch (0.3.1+) by updating documentation and cleaning up obsolete files.

## Commit Message

```
docs(cactus): Prepare for Cactus main branch migration

- Update README to reflect main branch capabilities and limitations
- Document breaking changes in CHANGELOG (vision/TTS removal, API changes)
- Add MAIN_BRANCH_MIGRATION.md with complete implementation guide
- Clean up obsolete documentation files
- Update pubspec.yaml to use Cactus GitHub main branch source

BREAKING CHANGES:
- Vision/multimodal support will be removed (use firebase_ai instead)
- TTS support will be removed (feature broken anyway)
- Model configuration changes from modelUrl to modelSlug
- Installation now requires GitHub source dependency

Migration guide: See MAIN_BRANCH_MIGRATION.md for complete checklist

Status: Documentation ready, code changes pending WiFi for flutter pub get
```

## Files to Stage

### Documentation (add these):
```bash
git add README.md
git add CHANGELOG.md
git add MAIN_BRANCH_MIGRATION.md
git add WORKSPACE_CLEAN.md
git rm DEVELOPMENT_PLAN.md  # Already deleted
```

### Configuration (add these):
```bash
git add pubspec.yaml
git add example/pubspec.yaml
```

### Keep Untracked (do NOT commit):
- `.flutter-plugins-dependencies` (generated files)
- `example/.flutter-plugins-dependencies` (generated files)
- `lib/src/cactus_tts_model.dart` (will be deleted during migration)
- Test files (incomplete, will be fixed during migration)
- Interface changes (separate commit scope)

## Optional: Clean Generated Files

```bash
# Remove generated files from git tracking
git restore .flutter-plugins-dependencies
git restore example/.flutter-plugins-dependencies
```

## Recommended Commit Commands

```bash
cd /Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_cactus

# Stage documentation changes
git add README.md CHANGELOG.md MAIN_BRANCH_MIGRATION.md WORKSPACE_CLEAN.md

# Stage deleted file
git rm DEVELOPMENT_PLAN.md

# Stage configuration changes
git add pubspec.yaml example/pubspec.yaml

# Restore generated files (don't commit)
git restore .flutter-plugins-dependencies example/.flutter-plugins-dependencies

# Review what will be committed
git status

# Commit
git commit -m "docs(cactus): Prepare for Cactus main branch migration

- Update README to reflect main branch capabilities and limitations
- Document breaking changes in CHANGELOG (vision/TTS removal, API changes)
- Add MAIN_BRANCH_MIGRATION.md with complete implementation guide
- Clean up obsolete documentation files
- Update pubspec.yaml to use Cactus GitHub main branch source

BREAKING CHANGES:
- Vision/multimodal support will be removed (use firebase_ai instead)
- TTS support will be removed (feature broken anyway)
- Model configuration changes from modelUrl to modelSlug
- Installation now requires GitHub source dependency

Status: Documentation ready, code changes pending WiFi"
```

## What's NOT in This Commit

The actual code changes will come in a **separate commit** after:
1. Successfully running `flutter pub get` with stable WiFi
2. Implementing the changes in MAIN_BRANCH_MIGRATION.md
3. Testing the refactored code
4. Verifying all tests pass

This keeps the documentation/prep work separate from the actual implementation.

## After This Commit

You can safely:
- ✅ Switch to another branch
- ✅ Work on other projects
- ✅ Return later to implement code changes

---

**Ready to commit!** 🚀
