#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"

PLATFORM=""
BUMP_TYPE="patch"
SKIP_CLEAN=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_mobile.sh --platform ios|android|both [options]

Options:
  --platform <ios|android|both>   Target platform to build.
  --bump <build|patch|minor|major>
                                   Version bump strategy. Default: patch.
  --skip-clean                     Skip flutter clean.
  --dry-run                        Print the next version and build commands without changing files.
  --help                           Show this help.

Examples:
  ./scripts/release_mobile.sh --platform ios
  ./scripts/release_mobile.sh --platform android --bump build
  ./scripts/release_mobile.sh --platform both --bump minor
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    --bump)
      BUMP_TYPE="${2:-}"
      shift 2
      ;;
    --skip-clean)
      SKIP_CLEAN=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PLATFORM" ]]; then
  echo "Missing required argument: --platform" >&2
  usage
  exit 1
fi

case "$PLATFORM" in
  ios|android|both) ;;
  *)
    echo "Invalid platform: $PLATFORM" >&2
    exit 1
    ;;
esac

case "$BUMP_TYPE" in
  build|patch|minor|major) ;;
  *)
    echo "Invalid bump type: $BUMP_TYPE" >&2
    exit 1
    ;;
esac

if [[ ! -f "$PUBSPEC_FILE" ]]; then
  echo "pubspec.yaml not found at $PUBSPEC_FILE" >&2
  exit 1
fi

if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "both" ]]; then
  if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "iOS builds require macOS." >&2
    exit 1
  fi
fi

CURRENT_VERSION_LINE="$(grep '^version:' "$PUBSPEC_FILE" | head -n 1 || true)"
if [[ -z "$CURRENT_VERSION_LINE" ]]; then
  echo "Could not find version line in pubspec.yaml" >&2
  exit 1
fi

CURRENT_VERSION="${CURRENT_VERSION_LINE#version: }"
VERSION_NAME="${CURRENT_VERSION%%+*}"
BUILD_NUMBER="${CURRENT_VERSION##*+}"

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NAME"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

case "$BUMP_TYPE" in
  build)
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
esac

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION_NAME="${MAJOR}.${MINOR}.${PATCH}"
NEW_VERSION="${NEW_VERSION_NAME}+${NEW_BUILD_NUMBER}"

ANDROID_COMMAND=(flutter build appbundle --release)
IOS_COMMAND=(flutter build ipa --release)

echo "Current version: $CURRENT_VERSION"
echo "Next version:    $NEW_VERSION"
echo "Platform:        $PLATFORM"
echo "Bump:            $BUMP_TYPE"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "Dry run only. No files changed."
  if [[ "$PLATFORM" == "android" || "$PLATFORM" == "both" ]]; then
    echo "Android command: ${ANDROID_COMMAND[*]}"
  fi
  if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "both" ]]; then
    echo "iOS command:     ${IOS_COMMAND[*]}"
  fi
  exit 0
fi

python3 - "$PUBSPEC_FILE" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re
import sys

pubspec_path = Path(sys.argv[1])
new_version = sys.argv[2]
content = pubspec_path.read_text()
updated, count = re.subn(r'^version:\s*.+$', f'version: {new_version}', content, count=1, flags=re.MULTILINE)
if count != 1:
    raise SystemExit('Failed to update version line in pubspec.yaml')
pubspec_path.write_text(updated)
PY

cleanup() {
  :
}
trap cleanup EXIT

echo ""
echo "Updated pubspec.yaml to $NEW_VERSION"

cd "$ROOT_DIR"

if [[ "$SKIP_CLEAN" -eq 0 ]]; then
  echo ""
  echo "Running flutter clean..."
  flutter clean
fi

echo ""
echo "Running flutter pub get..."
flutter pub get

if [[ "$PLATFORM" == "android" || "$PLATFORM" == "both" ]]; then
  if [[ ! -f "$ROOT_DIR/android/key.properties" ]]; then
    echo "android/key.properties not found." >&2
    exit 1
  fi
  if [[ ! -f "$ROOT_DIR/android/app/upload-keystore.jks" ]]; then
    echo "android/app/upload-keystore.jks not found." >&2
    exit 1
  fi

  echo ""
  echo "Building Android release bundle..."
  "${ANDROID_COMMAND[@]}"
  echo "Android output: build/app/outputs/bundle/release/app-release.aab"
fi

if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "both" ]]; then
  echo ""
  echo "Building iOS release IPA..."
  "${IOS_COMMAND[@]}"
  echo "iOS output: build/ios/ipa"
fi

echo ""
echo "Release build finished with version $NEW_VERSION"
