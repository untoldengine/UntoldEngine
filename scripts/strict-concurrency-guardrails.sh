#!/usr/bin/env bash
#
# strict-concurrency-guardrails.sh
#
# Runs a clean strict-concurrency build and produces:
# - .build/strict-concurrency.log
# - .build/strict-concurrency-summary.md
# - .build/strict-concurrency-metrics.json
#
# Optional guardrail:
#   MAX_UNIQUE_CONCURRENCY_WARNINGS=<N>
#   Fails if unique Swift warning sites exceed N.
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$ROOT_DIR/.build"
LOG_PATH="${STRICT_CONCURRENCY_LOG_PATH:-$BUILD_DIR/strict-concurrency.log}"
SUMMARY_PATH="${STRICT_CONCURRENCY_SUMMARY_PATH:-$BUILD_DIR/strict-concurrency-summary.md}"
METRICS_PATH="${STRICT_CONCURRENCY_METRICS_PATH:-$BUILD_DIR/strict-concurrency-metrics.json}"

mkdir -p "$BUILD_DIR"

count_pattern() {
  local pattern="$1"
  local file="$2"
  { grep -Eo "$pattern" "$file" || true; } | wc -l | tr -d ' '
}

echo "Running clean strict-concurrency build..."
swift package clean

set +e
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency 2>&1 | tee "$LOG_PATH"
build_status=${PIPESTATUS[0]}
set -e

if [ "$build_status" -ne 0 ]; then
  echo "Strict-concurrency build failed with status $build_status"
  exit "$build_status"
fi

swift_warning_pattern='^/.+\.swift:[0-9]+:[0-9]+: warning:'

total_warning_lines="$(count_pattern '^.*warning:' "$LOG_PATH")"
swift_warning_lines="$(count_pattern "$swift_warning_pattern" "$LOG_PATH")"
unique_warning_sites="$( { grep -E "$swift_warning_pattern" "$LOG_PATH" || true; } | sort -u | wc -l | tr -d ' ' )"
unique_warning_messages="$( { grep -E "$swift_warning_pattern" "$LOG_PATH" || true; } | sed -E 's#^/.+\.swift:[0-9]+:[0-9]+: warning: ##' | sort -u | wc -l | tr -d ' ' )"

mutable_global_count="$(count_pattern '\[#MutableGlobalVariable\]' "$LOG_PATH")"
sendable_capture_count="$(count_pattern '\[#SendableClosureCaptures\]' "$LOG_PATH")"
sending_race_count="$(count_pattern '\[#SendingRisksDataRace\]' "$LOG_PATH")"
actor_isolated_count="$(count_pattern '\[#ActorIsolatedCall\]' "$LOG_PATH")"

top_files="$(
  { grep -E "$swift_warning_pattern" "$LOG_PATH" || true; } \
    | sort -u \
    | sed -E 's#^(.+\.swift):[0-9]+:[0-9]+: warning:.*#\1#' \
    | sort \
    | uniq -c \
    | sort -nr \
    | head -n 10
)"

cat > "$METRICS_PATH" <<EOF
{
  "total_warning_lines": $total_warning_lines,
  "swift_warning_lines": $swift_warning_lines,
  "unique_warning_sites": $unique_warning_sites,
  "unique_warning_messages": $unique_warning_messages,
  "diagnostic_tags": {
    "MutableGlobalVariable": $mutable_global_count,
    "SendableClosureCaptures": $sendable_capture_count,
    "SendingRisksDataRace": $sending_race_count,
    "ActorIsolatedCall": $actor_isolated_count
  }
}
EOF

{
  echo "## Swift 6 Strict-Concurrency Guardrails"
  echo
  echo "- Build result: pass"
  echo "- Total warning lines: $total_warning_lines"
  echo "- Swift warning lines: $swift_warning_lines"
  echo "- Unique warning sites: $unique_warning_sites"
  echo "- Unique warning messages: $unique_warning_messages"
  echo
  echo "### Key diagnostic tags"
  echo
  echo "- \`MutableGlobalVariable\`: $mutable_global_count"
  echo "- \`SendableClosureCaptures\`: $sendable_capture_count"
  echo "- \`SendingRisksDataRace\`: $sending_race_count"
  echo "- \`ActorIsolatedCall\`: $actor_isolated_count"
  echo
  echo "### Top files by warning-site count"
  echo
  echo "| Count | File |"
  echo "|---:|---|"
  if [ -n "$top_files" ]; then
    while IFS= read -r line; do
      count="$(echo "$line" | awk '{print $1}')"
      file="$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}')"
      echo "| $count | \`$file\` |"
    done <<< "$top_files"
  fi
  echo
  echo "Artifacts:"
  echo "- \`$LOG_PATH\`"
  echo "- \`$SUMMARY_PATH\`"
  echo "- \`$METRICS_PATH\`"
} > "$SUMMARY_PATH"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "total_warning_lines=$total_warning_lines"
    echo "swift_warning_lines=$swift_warning_lines"
    echo "unique_warning_sites=$unique_warning_sites"
    echo "unique_warning_messages=$unique_warning_messages"
  } >> "$GITHUB_OUTPUT"
fi

if [ -n "${MAX_UNIQUE_CONCURRENCY_WARNINGS:-}" ]; then
  if [ "$unique_warning_sites" -gt "$MAX_UNIQUE_CONCURRENCY_WARNINGS" ]; then
    echo "Guardrail failed: unique warning sites ($unique_warning_sites) exceed budget ($MAX_UNIQUE_CONCURRENCY_WARNINGS)."
    exit 1
  fi
fi

echo "Guardrail check complete."
