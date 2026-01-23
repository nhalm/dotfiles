# Retry Methods Reference

Generated repositories include retry variants of all CRUD operations for handling transient failures.

## Available Retry Methods

Every table repository generates these retry methods:

| Standard Method | Retry Variant |
|-----------------|---------------|
| `Create` | `CreateWithRetry` |
| `Get` | `GetWithRetry` |
| `Update` | `UpdateWithRetry` |
| `Delete` | `DeleteWithRetry` |
| `List` | `ListWithRetry` |

## Usage

All methods (standard and retry) require `db pgxkit.Executor` as second parameter:

```go
// Standard - fails immediately on transient error
user, err := repo.Get(ctx, db, userID)

// With retry - automatically retries transient failures
user, err := repo.GetWithRetry(ctx, db, userID)
```

## Default Configuration

```go
var DefaultRetryConfig = RetryConfig{
    MaxRetries: 3,
    BaseDelay:  100 * time.Millisecond,
}
```

- **Max retries**: 3 attempts before failing
- **Base delay**: 100ms initial delay
- **Backoff**: Exponential (100ms → 200ms → 400ms)

## Retryable Errors

Retry methods automatically retry on these transient failures:

| PostgreSQL Code | Error | Description |
|-----------------|-------|-------------|
| `40001` | serialization_failure | Concurrent transaction conflict |
| `40P01` | deadlock_detected | Database deadlock |
| `53000` | insufficient_resources | Temporary resource exhaustion |
| `53100` | disk_full | Disk space temporarily unavailable |
| `53200` | out_of_memory | Memory temporarily unavailable |
| `53300` | too_many_connections | Connection limit reached |

Also retries on:
- `context.DeadlineExceeded`
- Connection closed/reset/timeout errors

## Non-Retryable Errors

These errors fail immediately (no retry):
- `ErrNotFound` - Row doesn't exist
- `ErrAlreadyExists` - Unique constraint violation
- `ErrInvalidReference` - Foreign key violation
- All other PostgreSQL errors

## When to Use Retry Methods

**Use retry methods for:**
- Background jobs and workers
- Operations where brief delays are acceptable
- High-concurrency scenarios with potential conflicts

**Use standard methods for:**
- User-facing requests (where you want fast failure)
- Operations that must not be delayed
- When you need custom retry logic

## Transactions and Retry

**Do NOT use retry methods inside transactions.** Once a PostgreSQL transaction encounters an error, it enters an aborted state and all subsequent commands will fail until ROLLBACK.

```go
// WRONG - retry inside transaction won't help
tx, _ := db.Begin(ctx)
repo := generated.NewUsersRepository(nil)
user, err := repo.GetWithRetry(ctx, tx, userID)  // If first attempt fails, retries will also fail

// CORRECT - retry the entire transaction
func createUserWithRetry(ctx context.Context, db *pgxkit.DB, params CreateParams) (*User, error) {
    return generated.RetryOperation(ctx, generated.DefaultRetryConfig, "create-user-tx",
        func(ctx context.Context) (*User, error) {
            tx, err := db.Begin(ctx)
            if err != nil {
                return nil, err
            }
            defer tx.Rollback(ctx)

            repo := generated.NewUsersRepository(nil)
            user, err := repo.Create(ctx, tx, params)  // Pass tx to method, not constructor
            if err != nil {
                return nil, err
            }

            if err := tx.Commit(ctx); err != nil {
                return nil, err
            }
            return user, nil
        })
}
```

**Rule:** Retry at the transaction boundary, not inside it.

## Custom Retry Logic

The generated `RetryOperation` and `RetryOperationSlice` functions are exported for custom use:

```go
// Custom retry with different config
config := generated.RetryConfig{
    MaxRetries: 5,
    BaseDelay:  50 * time.Millisecond,
}

result, err := generated.RetryOperation(ctx, config, "custom-op", func(ctx context.Context) (*MyType, error) {
    return doSomething(ctx)
})
```

## Example: Background Worker

```go
func (w *Worker) ProcessUser(ctx context.Context, userID uuid.UUID) error {
    // Use retry for background processing - pass w.db to method
    user, err := w.repo.GetWithRetry(ctx, w.db, userID)
    if err != nil {
        if generated.IsNotFound(err) {
            // Not found - don't retry, it won't appear
            return fmt.Errorf("user not found: %s", userID)
        }
        // After 3 retries, still failing
        return fmt.Errorf("failed to get user after retries: %w", err)
    }

    // Process user...
    return nil
}
```

## Example: API Handler

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    // Use standard method for fast user feedback - pass h.db to method
    user, err := h.repo.Get(r.Context(), h.db, userID)
    if err != nil {
        // Fail fast - don't make user wait for retries
        handleError(w, err)
        return
    }

    respondJSON(w, user)
}
```
