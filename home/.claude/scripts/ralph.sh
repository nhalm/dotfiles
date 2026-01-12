#!/usr/bin/env zsh
set -euo pipefail

MAX_ITERATIONS="${1:-20}"
ITERATION=0
STATUS_FILE="RALPH_STATUS.json"
PROMPT_FILE="PROMPT.md"

# Check required files
for file in "$PROMPT_FILE" "PRD.json" "TASKS.md" "PROGRESS.md"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: $file not found."
    echo "Run /ralph in Claude first to set up the project."
    exit 1
  fi
done

echo "=== Starting Ralph (max $MAX_ITERATIONS iterations) ==="

while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
  ((ITERATION++))
  echo ""
  echo "=== Iteration $ITERATION/$MAX_ITERATIONS ==="
  echo "Started: $(date)" >> ralph.log

  # Clear previous status
  rm -f "$STATUS_FILE"

  # Run Claude with the prompt
  cat "$PROMPT_FILE" | claude --dangerously-skip-permissions

  echo "Completed: $(date)" >> ralph.log

  # Validate status file
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "ERROR: Agent did not produce $STATUS_FILE - retrying"
    continue
  fi

  # Parse status
  STATUS=$(jq -r '.status' "$STATUS_FILE" 2>/dev/null || echo "INVALID")
  TESTS_PASSED=$(jq -r '.tests_passed' "$STATUS_FILE" 2>/dev/null || echo "false")
  TASK=$(jq -r '.task_completed' "$STATUS_FILE" 2>/dev/null || echo "unknown")

  if [[ "$STATUS" == "INVALID" ]]; then
    echo "ERROR: Invalid status file - retrying"
    continue
  fi

  echo "Task: $TASK"
  echo "Tests passed: $TESTS_PASSED"

  if [[ "$TESTS_PASSED" != "true" ]]; then
    echo "WARNING: Tests did not pass"
  fi

  if [[ "$STATUS" == "ALL_COMPLETE" ]]; then
    echo ""
    echo "=== All tasks complete after $ITERATION iterations ==="
    exit 0
  fi

  if [[ "$STATUS" == "BLOCKED" ]]; then
    REASON=$(jq -r '.blocked_reason' "$STATUS_FILE" 2>/dev/null || echo "unknown")
    echo ""
    echo "=== BLOCKED - Human intervention needed ==="
    echo "Reason: $REASON"
    exit 2
  fi

  sleep 2
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
exit 1
