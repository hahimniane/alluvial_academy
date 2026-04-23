#!/usr/bin/env bash
#
# Architectural fitness check — enforces the hard bans in AGENTS.md §2.
#
# Strategy: RATCHET. Only fails on NEW violations (files added in this PR),
# so pre-existing tech debt doesn't block the project. This means any AI
# agent or human who tries to add code in the wrong place gets stopped at
# CI, regardless of which tool they used.
#
# Exits 0 if clean, 1 if any new violation is found.

set -euo pipefail

# Determine the base ref to diff against.
# In GitHub Actions PR context, GITHUB_BASE_REF is the target branch (e.g. "main").
# In push-to-main context, there are no "added files vs itself" — skip entirely.
BASE_REF="${GITHUB_BASE_REF:-}"
if [ -z "$BASE_REF" ]; then
  # Fallback for local use: diff vs origin/main
  BASE_REF="main"
fi

# Make sure we have the base branch locally.
git fetch --no-tags --depth=1 origin "$BASE_REF" 2>/dev/null || true

# Collect files ADDED (A) in this PR. Ignore deletions and renames.
ADDED_FILES=$(git diff --diff-filter=A --name-only "origin/$BASE_REF...HEAD" 2>/dev/null || echo "")

if [ -z "$ADDED_FILES" ]; then
  echo "✅ No new files in this change — architecture check skipped."
  exit 0
fi

echo "→ Checking architectural rules on $(echo "$ADDED_FILES" | wc -l | tr -d ' ') new file(s)..."

fail=0
violations=""

while IFS= read -r file; do
  [ -z "$file" ] && continue

  # RULE 1: No new .dart files directly in lib/ root
  # Allowed: main.dart, firebase_options*.dart (generated)
  if [[ "$file" =~ ^lib/[^/]+\.dart$ ]]; then
    basename=$(basename "$file")
    case "$basename" in
      main.dart|firebase_options.dart|firebase_options_dev.dart)
        ;;
      *)
        violations+="  ❌ $file — new .dart files must live under lib/features/<feature>/ or lib/core/, not lib/ root\n"
        fail=1
        ;;
    esac
  fi

  # RULE 2: No new files in forbidden lib/ subdirs
  for forbid in lib/admin/ lib/widgets/ lib/utility_functions/ lib/screens/; do
    if [[ "$file" == "$forbid"* ]]; then
      violations+="  ❌ $file — forbidden directory '$forbid'. Move to lib/features/<feature>/\n"
      fail=1
    fi
  done

  # RULE 3: No new .js files in functions/ root (allowed: index.js, jest.config.js)
  if [[ "$file" =~ ^functions/[^/]+\.js$ ]]; then
    basename=$(basename "$file")
    case "$basename" in
      index.js|jest.config.js)
        ;;
      *)
        violations+="  ❌ $file — production handlers go in functions/handlers/; dev/migration scripts go in functions/dev-scripts/; tests go in functions/tests/\n"
        fail=1
        ;;
    esac
  fi

  # RULE 4: Cross-feature imports are handled by a Dart grep below, not per-file

done <<< "$ADDED_FILES"

# RULE 4: Cross-feature imports
# Check whether any Dart file under lib/features/<A>/ imports from lib/features/<B>/
# Only inspect added OR modified Dart files in features.
CHANGED_DART=$(git diff --diff-filter=AM --name-only "origin/$BASE_REF...HEAD" 2>/dev/null | grep -E '^lib/features/[^/]+/.+\.dart$' || true)
if [ -n "$CHANGED_DART" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Extract this file's feature name: lib/features/<feature>/...
    this_feature=$(echo "$file" | sed -E 's|lib/features/([^/]+)/.*|\1|')
    # Grep for imports of another feature (package: or relative)
    bad_imports=$(grep -nE "import ['\"](package:[^/]+/features/|\.\./\.\./features/|\.\./features/)" "$file" 2>/dev/null \
      | grep -vE "features/${this_feature}/" || true)
    if [ -n "$bad_imports" ]; then
      while IFS= read -r line; do
        violations+="  ❌ $file — cross-feature import (move shared code to lib/core/):\n      $line\n"
        fail=1
      done <<< "$bad_imports"
    fi
  done <<< "$CHANGED_DART"
fi

# Report
if [ $fail -eq 0 ]; then
  echo "✅ All architecture checks passed."
  exit 0
fi

echo ""
echo "Architecture violations found:"
echo -e "$violations"
echo ""
echo "See AGENTS.md §2 for the rules. If you believe this is a false positive,"
echo "discuss in the PR before merging."
exit 1
