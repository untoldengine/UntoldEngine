#!/usr/bin/env bash
#
# -------------------------------------------------------------
#  next-version.sh
# -------------------------------------------------------------
#  Description:
#    Determines the next semantic version of the Untold Engine
#    by comparing the current base ref (release/x.y.z branch or vX.Y.Z tag)
#    against the latest commits in develop.
#
#    The script scans commit messages between the release branch
#    and develop for keywords that indicate the bump level:
#      [API Change] → major
#      [Feature]    → minor
#      [Patch]/[Bugfix] → patch
#
#    It then prints the next version number (e.g. 0.3.1),
#    optionally prefixed with "v" if the --with-v flag is used.
#
#  Optional Flags:
#    --with-v   : Print version with 'v' prefix (e.g. v0.3.1)
#    --cliff    : Run git-cliff to prepend a changelog section
#                 for the new version based on recent commits
#    --docs     : Run Docusaurus docs:version command to
#                 snapshot documentation for the new release
#
#  Usage Examples:
#    ./scripts/next-version.sh               # auto-picks latest vX.Y.Z tag from develop
#    ./scripts/next-version.sh --with-v
#    ./scripts/next-version.sh release/0.3.0 --cliff
#    ./scripts/next-version.sh v0.3.0 --cliff --docs
#
#  Notes:
#    - Must be executed from the repository root.
#    - Base ref can be a release/x.y.z branch or vX.Y.Z tag.
#    - Designed to simplify the Untold Engine release flow by
#      automating version calculation, changelog generation, and
#      docs versioning in a single step.
#
# -------------------------------------------------------------

set -euo pipefail

WITH_V="false"
DO_CLIFF="false"
DO_DOCS="false"
BASE_REF=""

for arg in "$@"; do
  case "$arg" in
    --with-v) WITH_V="true" ;;
    --cliff)  DO_CLIFF="true" ;;
    --docs)   DO_DOCS="true" ;;
    release/*) BASE_REF="$arg" ;;
    v[0-9]*|[0-9]*.[0-9]*.[0-9]*) BASE_REF="$arg" ;; # allow tags like v0.3.0 or 0.3.0
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Auto-pick latest reachable tag (vX.Y.Z) from develop if none provided
if [[ -z "${BASE_REF}" ]]; then
  BASE_REF="$(git describe --tags --match 'v[0-9]*' --abbrev=0 develop 2>/dev/null || true)"
fi
[[ -n "${BASE_REF}" ]] || { echo "No base ref found. Pass a release branch (release/x.y.z) or tag (vX.Y.Z)." >&2; exit 1; }

# Parse base version from branch or tag name
if [[ "${BASE_REF}" =~ ^release/([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  BASE_MAJOR="${BASH_REMATCH[1]}"
  BASE_MINOR="${BASH_REMATCH[2]}"
  BASE_PATCH="${BASH_REMATCH[3]}"
elif [[ "${BASE_REF}" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  BASE_MAJOR="${BASH_REMATCH[1]}"
  BASE_MINOR="${BASH_REMATCH[2]}"
  BASE_PATCH="${BASH_REMATCH[3]}"
else
  echo "Base ref must look like release/x.y.z or vX.Y.Z (got: ${BASE_REF})" >&2
  exit 1
fi

# Ensure develop exists locally
git rev-parse --verify develop >/dev/null 2>&1 || { echo "Local branch 'develop' not found." >&2; exit 1; }

# Collect commit messages BASE..develop (local)
LOG="$(git log --pretty=%B "${BASE_REF}..develop" || true)"

# Highest bump wins
if echo "$LOG" | grep -q "\[API Change\]"; then
  LEVEL="major"
elif echo "$LOG" | grep -q "\[Feature\]"; then
  LEVEL="minor"
elif echo "$LOG" | grep -q "\[Patch\]"; then
  LEVEL="patch"
elif echo "$LOG" | grep -q "\[Bugfix\]"; then
  LEVEL="patch"
else
  LEVEL="patch"
fi

# Compute NEXT from BASE + bump
case "$LEVEL" in
  major) NEXT="$((BASE_MAJOR+1)).0.0" ;;
  minor) NEXT="${BASE_MAJOR}.$((BASE_MINOR+1)).0" ;;
  patch) NEXT="${BASE_MAJOR}.${BASE_MINOR}.$((BASE_PATCH+1))" ;;
  *) echo "Unknown bump level: $LEVEL" >&2; exit 1 ;;
esac

# Print next version (default behavior)
if [[ "${WITH_V}" == "true" ]]; then
  echo "v${NEXT}"
else
  echo "${NEXT}"
fi

# Optionally run git-cliff to prepend changelog for BASE..HEAD
if [[ "${DO_CLIFF}" == "true" ]]; then
  command -v git-cliff >/dev/null 2>&1 || { echo "git-cliff not found. Install it first." >&2; exit 1; }
  TAG="v${NEXT}"
  RANGE="${BASE_REF}..HEAD"
  git cliff "${RANGE}" --tag "${TAG}" --prepend CHANGELOG.md
fi

# Optionally run Docusaurus docs:version
if [[ "${DO_DOCS}" == "true" ]]; then
  command -v npm >/dev/null 2>&1 || { echo "npm not found. Please install Node.js." >&2; exit 1; }

  DOCS_DIR="website"
  if [[ -d "${DOCS_DIR}" && -f "${DOCS_DIR}/package.json" ]]; then
    echo "🧭 Running Docusaurus versioning for ${NEXT} (in ${DOCS_DIR})..."
    (
      cd "${DOCS_DIR}"
      npm run docusaurus docs:version "${NEXT}"
    )
  else
    echo "🧭 Running Docusaurus versioning for ${NEXT} (current directory)..."
    npm run docusaurus docs:version "${NEXT}"
  fi

  echo "✅ Docusaurus version ${NEXT} created."
fi
