#!/usr/bin/env bash
# -------------------------------------------------------------
#  enforce-commit-prefix.sh
# -------------------------------------------------------------
#  Ensures all commit messages follow Untold Engine's standard
#  prefix format (e.g., [Feature], [Bugfix], [Docs], etc.)
#  Works with pre-commit's commit-msg hook.
# -------------------------------------------------------------

set -eo pipefail

# Use passed file or fallback to default Git path
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

# Read the first line of the commit message
COMMIT_MSG="$(head -n1 "$COMMIT_MSG_FILE")"

# Define valid prefixes
VALID_PREFIXES='^\[(Feature|Patch|Bugfix|API[[:space:]]Change|Docs|Release|Refactor|Chores|CI|Test|Performance|Security)\]'

# Validate prefix
if [[ ! "$COMMIT_MSG" =~ $VALID_PREFIXES ]]; then
  echo "❌ Invalid commit message."
  echo
  echo "Each commit message must start with one of these prefixes:"
  echo "  [Feature]      – for new features"
  echo "  [Patch]        – for small, safe fixes"
  echo "  [Bugfix]       – for fixing bugs"
  echo "  [API Change]   – for breaking API updates"
  echo "  [Docs]         – for documentation updates"
  echo "  [Refactor]     – for internal code restructuring"
  echo "  [Chores]       – for maintenance tasks, cleanup, or tool updates"
  echo "  [CI]           – for continuous integration or workflow changes"
  echo "  [Test]         – for adding or updating tests"
  echo "  [Performance]  – for performance improvements"
  echo "  [Security]     – for security-related fixes"
  echo "  [Release]      - for releases"
  echo
  echo "Example:"
  echo "  [Feature] Add dynamic shadow rendering"
  echo "  [Docs] Update README with installation guide"
  exit 1
fi

echo "✅ Commit message prefix valid."

