#!/usr/bin/env zsh
set -euo pipefail

STATUS_FILE="RALPH_STATUS.json"
PROMPT_FILE="PROMPT.md"
PRD_FILE="PRD.json"
TASKS_FILE="TASKS.md"
PROGRESS_FILE="PROGRESS.md"

usage() {
  echo "Usage: ralph.sh [OPTIONS] [MAX_ITERATIONS]"
  echo ""
  echo "Options:"
  echo "  --setup-only    Create setup files but don't run the loop"
  echo "  --help          Show this help message"
  echo ""
  echo "Arguments:"
  echo "  MAX_ITERATIONS  Maximum loop iterations (default: 20)"
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
  if ! jq -e '.title' "$PRD_FILE" > /dev/null 2>&1; then
    echo "ERROR: $PRD_FILE missing 'title' field"
    exit 1
  fi
  if ! jq -e '.tasks | length > 0' "$PRD_FILE" > /dev/null 2>&1; then
    echo "ERROR: $PRD_FILE has no tasks"
    exit 1
  fi

  # Archive existing files
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  ARCHIVED=()

  for file in "$TASKS_FILE" "$PROGRESS_FILE" "$STATUS_FILE" "ralph.log"; do
    if [[ -f "$file" ]]; then
      mkdir -p archive
      ARCHIVE_NAME="archive/${file%.*}_${TIMESTAMP}.${file##*.}"
      mv "$file" "$ARCHIVE_NAME"
      ARCHIVED+=("$file -> $ARCHIVE_NAME")
    fi
  done

  if [[ ${#ARCHIVED[@]} -gt 0 ]]; then
    echo "Archived:"
    for item in "${ARCHIVED[@]}"; do
      echo "  $item"
    done
  fi

  # Create TASKS.md from PRD.json
  PRD_TITLE=$(jq -r '.title' "$PRD_FILE")
  {
    echo "# Implementation Tasks"
    echo ""
    echo "Generated from $PRD_FILE"
    echo ""
    echo "## Tasks"
    jq -r '.tasks[] | "- [ ] \(.description)"' "$PRD_FILE"
  } > "$TASKS_FILE"

  TASK_COUNT=$(jq '.tasks | length' "$PRD_FILE")
  echo "Created $TASKS_FILE ($TASK_COUNT tasks)"

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
# Agent Instructions

You are an autonomous agent implementing features from a PRD. Follow this workflow exactly.

## Phase 1: Context Loading
1. Read `PRD.json` to understand the overall feature
2. Read `TASKS.md` to see remaining work
3. Read `PROGRESS.md` to see what previous agents completed

## Phase 2: Planning
1. Select the NEXT incomplete task from TASKS.md
2. Create a brief implementation plan for that task
3. Proceed to implementation

## Phase 3: Implementation
1. Implement your plan
2. Keep changes focused on the single task

## Phase 4: Testing (MANDATORY)
1. If `Makefile` exists, run `make test` or equivalent target
2. If integration tests exist, run them
3. Run any project-specific test commands
4. **YOU MUST ACTUALLY RUN THE TESTS** - do not assume they pass
5. **RECORD THE ACTUAL OUTPUT** - copy test results to verify
6. If tests fail, fix them before proceeding

## Phase 5: Self-Review (MANDATORY)
Review your own work HONESTLY:
- **DO NOT LIE** about test results or code quality
- **DO NOT ASSUME** things work without verification
- **ACTUALLY CHECK** that your changes compile/run
- Code quality: Is the code clean, readable, idiomatic?
- Documentation: Are complex parts documented? Are public APIs documented?
- Test coverage: Do tests cover the HOT PATH and HIGH RISK areas?
- Fix any issues found

## Phase 6: Finalization
1. Append to `PROGRESS.md`:
   - What task you completed
   - Key decisions made
   - Actual test results (pass/fail counts)
   - Any blockers or notes for next agent
2. Mark the task complete in `TASKS.md` (change `- [ ]` to `- [x]`)
3. Commit with message: `feat: <task summary>`

## Phase 7: Status Report (REQUIRED)
You MUST create `RALPH_STATUS.json` with this exact format:
```json
{
  "status": "TASK_COMPLETE|ALL_COMPLETE|BLOCKED",
  "task_completed": "description of task",
  "tests_passed": true|false,
  "tests_output": "summary of test results",
  "commit_hash": "abc123 or null if no commit",
  "blocked_reason": "only if status is BLOCKED"
}
```

Status values:
- `TASK_COMPLETE`: This task done, more tasks remain
- `ALL_COMPLETE`: All tasks in TASKS.md are done
- `BLOCKED`: Cannot proceed without human help

## Rules
- ONE task per iteration
- Always commit your work
- Never skip testing
- **NEVER LIE IN STATUS REPORT** - if tests failed, report tests_passed: false
- If stuck, set status to BLOCKED with reason
PROMPT_EOF

  echo "Created $PROMPT_FILE"

  # Update .gitignore if it exists
  if [[ -f ".gitignore" ]]; then
    GITIGNORE_ENTRIES=(
      "PRD.json"
      "RALPH_STATUS.json"
      "ralph.log"
      "archive/"
      "PROMPT.md"
      "TASKS.md"
      "PROGRESS.md"
    )
    ADDED=()
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
      if ! grep -qxF "$entry" .gitignore; then
        echo "$entry" >> .gitignore
        ADDED+=("$entry")
      fi
    done
    if [[ ${#ADDED[@]} -gt 0 ]]; then
      echo "Added to .gitignore: ${ADDED[*]}"
    fi
  fi

  echo ""
  echo "=== Setup complete ==="
}

# Parse arguments
SETUP_ONLY=false
MAX_ITERATIONS=20

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

# Always run setup if files don't exist
if [[ ! -f "$PROMPT_FILE" ]] || [[ ! -f "$TASKS_FILE" ]] || [[ ! -f "$PROGRESS_FILE" ]]; then
  setup
elif [[ "$SETUP_ONLY" == true ]]; then
  setup
fi

if [[ "$SETUP_ONLY" == true ]]; then
  echo ""
  echo "To start the loop: ralph.sh"
  exit 0
fi

# Main loop
ITERATION=0
echo ""
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
