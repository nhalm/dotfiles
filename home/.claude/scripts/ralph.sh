#!/usr/bin/env zsh
set -uo pipefail

STATUS_FILE="RALPH_STATUS.json"
PROMPT_FILE="PROMPT.md"
PRD_FILE="PRD.json"
TASKS_FILE="TASKS.md"
PROGRESS_FILE="PROGRESS.md"

# Dependency checks
for cmd in jq claude; do
  command -v "$cmd" >/dev/null || { echo "ERROR: $cmd not found"; exit 1; }
done

# Cleanup on interrupt
cleanup() { [[ -n "${CLAUDE_PID:-}" ]] && kill $CLAUDE_PID 2>/dev/null; }
trap cleanup EXIT INT TERM

# Time formatting helper
format_time() { printf "%02d:%02d" $(($1 / 60)) $(($1 % 60)); }

usage() {
  echo "Usage: ralph.sh [OPTIONS] [MAX_ITERATIONS]"
  echo ""
  echo "Options:"
  echo "  --setup-only    Create setup files but don't run the loop"
  echo "  --help          Show this help message"
  echo ""
  echo "Arguments:"
  echo "  MAX_ITERATIONS  Maximum loop iterations (default: 30)"
}

setup() {
  echo "=== Setting up Ralph ==="

  # Validate PRD.json
  if [[ ! -f "$PRD_FILE" ]]; then
    echo "ERROR: $PRD_FILE not found."
    echo "Run /prd in Claude first to create it."
    exit 1
  fi

  # Validate PRD.json has required fields
  if ! jq -e '.title and (.tasks | length > 0)' "$PRD_FILE" >/dev/null 2>&1; then
    echo "ERROR: $PRD_FILE must have 'title' and at least one task"
    exit 1
  fi

  # Archive existing files
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  mkdir -p archive
  for file in "$TASKS_FILE" "$PROGRESS_FILE" "$STATUS_FILE" "ralph.log"; do
    [[ -f "$file" ]] && mv "$file" "archive/${file%.*}_${TIMESTAMP}.${file##*.}"
  done

  # Create TASKS.md from PRD.json (with task IDs)
  PRD_TITLE=$(jq -r '.title' "$PRD_FILE")
  {
    echo "# Implementation Tasks"
    echo ""
    echo "Generated from $PRD_FILE"
    echo ""
    echo "## Tasks"
    jq -r '.tasks[] | "- [ ] [\(.id)] \(.description)"' "$PRD_FILE"
  } > "$TASKS_FILE"

  TASK_COUNT=$(jq '.tasks | length' "$PRD_FILE")
  echo "Created $TASKS_FILE ($TASK_COUNT tasks)"

  # Create RALPH_STATUS.json with initial structure
  jq -n --arg title "$PRD_TITLE" '{prd_title: $title, iterations: []}' > "$STATUS_FILE"
  echo "Created $STATUS_FILE"

  # Create PROGRESS.md
  {
    echo "# Progress Log"
    echo ""
    echo "PRD: $PRD_TITLE"
    echo "Started: $(date)"
    echo ""
    echo "---"
  } > "$PROGRESS_FILE"

  echo "Created $PROGRESS_FILE"

  # Create PROMPT.md
  cat > "$PROMPT_FILE" << 'PROMPT_EOF'
# Autonomous Task Executor

Execute ONE task, verify, commit, exit. No conversation, explanations, or reflections.

## RULES
- ONLY tool calls and final RALPH_STATUS.json
- ONE task = ONE `- [ ] [ID] description` line in TASKS.md
- There is NO valid reason to do more than one task

## CONTEXT (read first)
PRD.json (esp. `out_of_scope`), TASKS.md, PROGRESS.md, RALPH_STATUS.json

## TASK SELECTION
First `- [ ] [ID] description` in TASKS.md. None → status=ALL_COMPLETE, exit.

## IMPLEMENTATION
- `out_of_scope` items → BLOCKED
- Minimal changes. No refactoring. If commit needs "and" → too much.

## TESTING
Full test suite. 3 fix attempts max → BLOCKED. Only fix tests you broke.

## FINALIZE
1. Mark `- [x]` in TASKS.md
2. Append to PROGRESS.md
3. `git add -A && git commit -m "feat: <task>"`

## STATUS REPORT
Append to RALPH_STATUS.json `iterations`:
`{"iteration":N,"status":"TASK_COMPLETE|ALL_COMPLETE|BLOCKED","task_id":N,"task_completed":"desc","tests_passed":bool,"tests_output":"summary","commit_hash":"abc","files_modified":[],"notes":"","blocked_reason":null}`

## VIOLATIONS
- Task "Add struct" → ALSO adds validation → ❌ multiple tasks
- Tests fail → tests_passed: true → ❌ lying
PROMPT_EOF

  echo "Created $PROMPT_FILE"

  # Update .gitignore if it exists
  if [[ -f ".gitignore" ]]; then
    for entry in PRD.json RALPH_STATUS.json ralph.log archive/ PROMPT.md TASKS.md PROGRESS.md; do
      grep -qxF "$entry" .gitignore || echo "$entry" >> .gitignore
    done
  fi

  echo ""
  echo "=== Setup complete ==="
}

# Parse arguments
SETUP_ONLY=false
MAX_ITERATIONS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --setup-only)
      SETUP_ONLY=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      if [[ $1 =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS=$1
      else
        echo "Unknown option: $1"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Run setup if files missing or --setup-only
[[ ! -f "$PROMPT_FILE" || ! -f "$TASKS_FILE" || ! -f "$PROGRESS_FILE" || "$SETUP_ONLY" == true ]] && setup
[[ "$SETUP_ONLY" == true ]] && { echo -e "\nTo start the loop: ralph.sh"; exit 0; }

# Main loop
ITERATION=0
TOTAL_TASKS=$(jq '.tasks | length' "$PRD_FILE")
echo ""
echo "=== Starting Ralph ($TOTAL_TASKS tasks, max $MAX_ITERATIONS iterations) ==="

while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
  ITERATION=$((ITERATION + 1))
  START_TIME=$(date +%s)
  COMPLETED_TASKS=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null) || COMPLETED_TASKS=0
  echo ""
  echo "=== Task $((COMPLETED_TASKS + 1))/$TOTAL_TASKS (iteration $ITERATION) ==="
  echo "Started: $(date)" >> ralph.log

  # Run Claude in background with iteration number prepended
  PROMPT_WITH_ITERATION="# ITERATION NUMBER: $ITERATION

$(cat "$PROMPT_FILE")"
  claude -p "$PROMPT_WITH_ITERATION" --dangerously-skip-permissions &
  CLAUDE_PID=$!

  # Show elapsed time while Claude runs
  while kill -0 $CLAUDE_PID 2>/dev/null; do
    printf "\r⏳ Running agent... $(format_time $(($(date +%s) - START_TIME)))"
    sleep 1
  done
  wait $CLAUDE_PID
  printf "\r✓ Completed in $(format_time $(($(date +%s) - START_TIME)))          \n"
  echo "Completed: $(date)" >> ralph.log

  # Validate status file
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "ERROR: Agent did not produce $STATUS_FILE - retrying"
    continue
  fi

  # Parse status (from last iteration in array)
  STATUS=$(jq -r '.iterations[-1].status // "INVALID"' "$STATUS_FILE" 2>/dev/null)
  TASK=$(jq -r '.iterations[-1].task_completed // "unknown"' "$STATUS_FILE" 2>/dev/null)

  echo "Task: $TASK"

  case "$STATUS" in
    TASK_COMPLETE)
      echo "Status: TASK_COMPLETE - continuing to next iteration"
      sleep 2
      ;;
    ALL_COMPLETE)
      echo ""
      echo "=== All tasks complete after $ITERATION iterations ==="
      exit 0
      ;;
    BLOCKED)
      REASON=$(jq -r '.iterations[-1].blocked_reason' "$STATUS_FILE" 2>/dev/null || echo "unknown")
      echo ""
      echo "=== BLOCKED - Human intervention needed ==="
      echo "Reason: $REASON"
      exit 2
      ;;
    *)
      echo "ERROR: Invalid status '$STATUS'"
      exit 1
      ;;
  esac
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
exit 1
