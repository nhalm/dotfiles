Prepare project for Ralph autonomous execution.

## Prerequisites
- PRD.json must exist (created via /prd command)

## Steps

### 1. Validate PRD.json
Read PRD.json and validate it has required fields:
- title
- tasks (array with at least one task)

If PRD.json doesn't exist, tell the user to run `/prd` first.

### 2. Archive Existing Ralph Files
If any of these files exist, move them to an `archive/` directory with timestamp:
- TASKS.md → archive/TASKS_YYYYMMDD_HHMMSS.md
- PROGRESS.md → archive/PROGRESS_YYYYMMDD_HHMMSS.md
- RALPH_STATUS.json → archive/RALPH_STATUS_YYYYMMDD_HHMMSS.json
- ralph.log → archive/ralph_YYYYMMDD_HHMMSS.log

Create the archive directory if it doesn't exist.

### 3. Create Fresh TASKS.md
Generate from PRD.json tasks array:
```markdown
# Implementation Tasks

Generated from PRD.json

## Tasks
- [ ] Task 1 description
- [ ] Task 2 description
...
```

### 4. Create Fresh PROGRESS.md
```markdown
# Progress Log

PRD: {title from PRD.json}
Started: {current timestamp}

---
```

### 5. Create PROMPT.md
Create the agent instructions file with this content:

```markdown
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
```

### 6. Final Output
After creating all files, output:

```
Ralph setup complete.

Files created:
- TASKS.md ({N} tasks)
- PROGRESS.md
- PROMPT.md

Archived files moved to: archive/

To start autonomous execution:
  ~/.claude/scripts/ralph.sh

Or with custom iteration limit:
  ~/.claude/scripts/ralph.sh 30
```
