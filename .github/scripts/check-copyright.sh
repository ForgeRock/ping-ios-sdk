#!/usr/bin/env bash

set -euo pipefail

CURRENT_YEAR=$(date +%Y)
if [[ -n "${BASE_SHA:-}" ]]; then
  echo "Checking copyright headers for files changed since: $BASE_SHA"
  CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_SHA"...HEAD)
else
  BASE_REF="${GITHUB_BASE_REF:-develop}"

  echo "Checking copyright headers for files changed against: $BASE_REF"

  git fetch origin "$BASE_REF"

  CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "origin/$BASE_REF"...HEAD)
fi

FAILED=0

for file in $CHANGED_FILES; do
  # Check only source files we care about
  case "$file" in
    *.kt|*.java|*.swift|*.h|*.m|*.mm|*.c|*.cc|*.cpp)
      ;;
    *)
      continue
      ;;
  esac

  # Skip files that no longer exist
  [[ -f "$file" ]] || continue

  echo "Checking: $file"

  # Require a Ping copyright header
  COPYRIGHT_LINE=$(grep -iE \
    'Copyright( \(c\))? [0-9]{4}([[:space:]]*-[[:space:]]*[0-9]{4})?[[:space:]]+Ping Identity( Corporation)?' \
    "$file" | head -1 || true)

  if [[ -z "$COPYRIGHT_LINE" ]]; then
    echo "::error file=$file::Missing or invalid Ping Identity copyright header"
    FAILED=1
    continue
  fi

  # Extract copyright years
  YEARS=$(echo "$COPYRIGHT_LINE" | grep -oE '[0-9]{4}([[:space:]]*-[[:space:]]*[0-9]{4})?' | head -1)

  START_YEAR=$(echo "$YEARS" | grep -oE '^[0-9]{4}')
  END_YEAR=$(echo "$YEARS" | grep -oE '[0-9]{4}$')

  if [[ "$END_YEAR" -lt "$CURRENT_YEAR" ]]; then
    if [[ "$START_YEAR" == "$END_YEAR" ]]; then
      EXPECTED="$START_YEAR - $CURRENT_YEAR"
    else
      EXPECTED="$START_YEAR - $CURRENT_YEAR"
    fi

    echo "::error file=$file::Copyright year is stale. Expected: $EXPECTED"
    FAILED=1
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo
  echo "Copyright validation failed."
  exit 1
fi

echo "Copyright validation passed."