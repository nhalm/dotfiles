Show the current status of a Ralph autonomous execution run.

## Steps

### 1. Check for Ralph Files
Check if the following files exist:
- RALPH_STATUS.json
- PROGRESS.md
- TASKS.md

If none exist, tell the user "No Ralph run detected in this directory. Run /ralph to set up."

### 2. Parse RALPH_STATUS.json (if exists)
Extract and display:
- Status (TASK_COMPLETE, ALL_COMPLETE, BLOCKED)
- Last completed task
- Tests passed (true/false)
- Blocked reason (if status is BLOCKED)

### 3. Parse TASKS.md
Count and display:
- Total tasks
- Completed tasks (lines with `- [x]`)
- Remaining tasks (lines with `- [ ]`)

### 4. Summarize PROGRESS.md
Read PROGRESS.md and provide a brief summary of:
- When the run started
- Key milestones completed
- Any noted blockers or issues

### 5. Output Format

```
=== Ralph Status ===

Last iteration: {status from RALPH_STATUS.json}
Last task: {task_completed}
Tests: {passed/failed}

Progress: {completed}/{total} tasks complete

Completed:
- [x] Task 1
- [x] Task 2

Remaining:
- [ ] Task 3
- [ ] Task 4

{If BLOCKED: "⚠️  BLOCKED: {reason}"}
```

If ralph.log exists, also show:
```
Last activity: {last timestamp from ralph.log}
```
