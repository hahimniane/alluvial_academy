#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_ALIAS="dev"

echo "Deploying Firestore rules/indexes + Functions to Firebase project alias: ${PROJECT_ALIAS}"
echo "Repo: ${REPO_ROOT}"
echo "This does NOT deploy hosting or storage rules."
echo "Note: Cloud Functions require the Blaze plan on the dev project."
echo

cd "${REPO_ROOT}"

firebase deploy --project "${PROJECT_ALIAS}" --only firestore:rules,firestore:indexes

# Prevent first-time Functions deploy from failing due to missing Artifact Registry cleanup policy.
# (Without this, deploy can succeed but still exit non-zero with a cleanup policy warning.)
firebase functions:artifacts:setpolicy --project "${PROJECT_ALIAS}" --force >/dev/null 2>&1 || true
firebase deploy --project "${PROJECT_ALIAS}" --only functions
