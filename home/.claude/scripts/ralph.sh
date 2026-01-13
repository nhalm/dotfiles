#!/usr/bin/env zsh
set -uo pipefail

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

You execute ONE task, verify it works, commit it, and exit. No conversation.

## OUTPUT RULES
- NO explanations of what you're about to do
- NO status updates like "Now I'm reading..."
- NO reflections like "Let me think about..."
- ONLY: Tool calls and the final RALPH_STATUS.json

---

## TASK DEFINITION (READ THIS CAREFULLY)

A "task" is ONE LINE in TASKS.md formatted as: `- [ ] [ID] description`
- The `[ID]` is the task number from PRD.json
- ONE LINE = ONE TASK
- NOT multiple lines, NOT "related tasks", NOT "subtasks"

---

## PHASE 1: Context Loading

Read silently (no commentary):
1. `PRD.json` - feature overview, goals, requirements
2. `TASKS.md` - task list with completion status
3. `PROGRESS.md` - detailed log of previous work
4. `RALPH_STATUS.json` (if exists) - previous iterations with notes and context

---

## PHASE 2: Task Selection

Execute this algorithm exactly:
1. Open TASKS.md
2. Scan from top to bottom
3. Find the FIRST line matching `- [ ] [ID] description`
4. Extract the ID number and description - this is your task
5. STOP READING - do not look at other tasks

**FORBIDDEN RATIONALIZATIONS** - If you think any of these, you are WRONG:
- "These tasks are related so I'll do them together"
- "Task B doesn't make sense without task A"
- "It's more efficient to batch these"
- "This task requires also doing task X"
- "While I'm here, I should also..."
- "This other task is only 2 lines of code"

There is NO valid reason to do more than one task.

---

## PHASE 3: Implementation

Implement ONLY the single task from Phase 2.

**CORE PRINCIPLE: Do LESS, not MORE.**
- If a task is vague, make the MINIMAL change that satisfies it
- Default to changing fewer files, not more
- If unsure about scope, set status=BLOCKED and ask

**FORBIDDEN:**
- NO refactoring - implement in the existing code structure
- NO "cleanup while I'm here"
- NO preparing infrastructure for future tasks
- NO updating docs unless the task explicitly says to
- NO installing dependencies unless the task explicitly requires them

**STOP SIGNALS** - If you notice yourself:
- Editing files unrelated to your specific task → STOP
- Planning to change something "while you're here" → STOP
- Writing code for the next task → STOP
- Your commit message would need "and" → STOP, you're doing multiple tasks
- Reading more than 5 files to understand context → STOP, execute literally

---

## PHASE 4: Testing

Run ALL tests - unit, integration, short, benchmarks. If they fail, fix them. Repeat until they pass.

```bash
# Run the full test suite - examples:
make test                    # if Makefile exists
go test ./... -race          # Go projects
npm test                     # Node projects
pytest                       # Python projects
```

Look for test commands in Makefile, package.json, or project docs.

**WORKFLOW:**
1. Run tests
2. If tests pass → proceed to Phase 5
3. If tests fail → analyze error, fix YOUR code, run tests again
4. **ATTEMPT LIMIT: 3 fix attempts max**
   - After 3 failed fixes, set status=BLOCKED
   - Log what you tried in notes

**IMPORTANT:**
- Only fix tests that YOUR changes broke
- If tests fail in unrelated areas → set status=BLOCKED, don't fix other code
- If no tests exist for your change → note this, proceed anyway
- You cannot mark a task complete until tests pass

---

## PHASE 5: Pre-Commit Check

Before committing, verify:
- [ ] I modified ONLY files necessary for this specific task
- [ ] I did NOT refactor, optimize, or improve anything outside the task
- [ ] I did NOT prepare anything for future tasks
- [ ] My commit will contain ONE task's worth of changes

If any check fails → revert extra changes before committing.

---

## PHASE 6: Finalize

1. **TASKS.md**: Change `- [ ]` to `- [x]` for your ONE task only
2. **PROGRESS.md**: Append entry with task completed, test results, notes
3. **Commit**: `git add -A && git commit -m "feat: <task summary>"`

---

## PHASE 7: Status Report

Read `RALPH_STATUS.json`, append your iteration to the `iterations` array, and write it back.

```json
{
  "prd_title": "Feature name",
  "iterations": [
    {
      "iteration": 1,
      "status": "TASK_COMPLETE",
      "task_id": 1,
      "task_completed": "exact task description",
      "tests_passed": true,
      "tests_output": "X passed, Y failed",
      "commit_hash": "abc123",
      "files_modified": ["path/to/file.go"],
      "notes": "Context for next iteration",
      "blocked_reason": null
    }
  ]
}
```

**FIELDS:**
- `iteration` - Use the ITERATION NUMBER from the prompt header
- `task_id` - The `[ID]` from the task line in TASKS.md
- `blocked_reason` - Only set if status is BLOCKED, otherwise null

**STATUS VALUES:**
- `TASK_COMPLETE` - Task done, tests pass, committed, more tasks remain
- `ALL_COMPLETE` - All tasks done, zero `- [ ]` lines remain in TASKS.md
- `BLOCKED` - Truly stuck: can't fix tests, missing deps, need human decision

---

## EXAMPLES

**CORRECT:**
```
Task: "Add User struct to types.go"
- Create User struct
- Run tests → exit code 0
- Commit → exit code 0, hash abc123
- Status: TASK_COMPLETE
```

**WRONG - Multiple tasks:**
```
Task: "Add User struct to types.go"
- Create User struct
- ALSO add validation (that's task 2)
- ALSO add tests (that's task 3)
❌ VIOLATION
```

**WRONG - Ignoring failure:**
```
- Run tests → exit code 1
- Report tests_passed: true
❌ LYING
```

**CORRECT - Handling failure:**
```
- Run tests → exit code 1
- Status: BLOCKED
- blocked_reason: "Tests failed: TestUser expected nil, got error"
```
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
TOTAL_TASKS=$(jq '.tasks | length' "$PRD_FILE")
echo ""
echo "=== Starting Ralph ($TOTAL_TASKS tasks, max $MAX_ITERATIONS iterations) ==="

while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
  ITERATION=$((ITERATION + 1))
  START_TIME=$(date +%s)
  COMPLETED_TASKS=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null || echo "0")
  REMAINING_TASKS=$((TOTAL_TASKS - COMPLETED_TASKS))
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
    ELAPSED=$(($(date +%s) - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECS=$((ELAPSED % 60))
    printf "\r⏳ Running agent... %02d:%02d" $MINUTES $SECS
    sleep 1
  done
  wait $CLAUDE_PID

  ELAPSED=$(($(date +%s) - START_TIME))
  MINUTES=$((ELAPSED / 60))
  SECS=$((ELAPSED % 60))
  printf "\r✓ Completed in %02d:%02d          \n" $MINUTES $SECS
  echo "Completed: $(date)" >> ralph.log

  # Validate status file
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "ERROR: Agent did not produce $STATUS_FILE - retrying"
    continue
  fi

  # Parse status (from last iteration in array)
  STATUS=$(jq -r '.iterations[-1].status' "$STATUS_FILE" 2>/dev/null || echo "INVALID")
  TESTS_PASSED=$(jq -r '.iterations[-1].tests_passed' "$STATUS_FILE" 2>/dev/null || echo "false")
  TASK=$(jq -r '.iterations[-1].task_completed' "$STATUS_FILE" 2>/dev/null || echo "unknown")

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
