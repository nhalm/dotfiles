# pgxkit Retry and Error Handling

Retry logic with functional options and structured errors.

**See also:** core.md (base query methods), types.md (NULL handling for validation)

## Retry Functions

```go
// Generic retry - returns value
result, err := pgxkit.Retry(ctx, func(ctx context.Context) (*User, error) {
    return fetchUser(ctx, userID)
}, pgxkit.WithMaxRetries(5))

// Void retry - returns only error
err := pgxkit.RetryOperation(ctx, func(ctx context.Context) error {
    return doSomething(ctx)
}, pgxkit.WithMaxRetries(5))
```

## Functional Options

```go
pgxkit.WithMaxRetries(n int)           // Max retry attempts (default: 3)
pgxkit.WithBaseDelay(d time.Duration)  // Initial delay (default: 100ms)
pgxkit.WithMaxDelay(d time.Duration)   // Delay cap (default: 1s)
pgxkit.WithBackoffMultiplier(m float64) // Backoff multiplier (default: 2.0)

// Example: custom config
err := pgxkit.RetryOperation(ctx, fn,
    pgxkit.WithMaxRetries(5),
    pgxkit.WithBaseDelay(50*time.Millisecond),
    pgxkit.WithMaxDelay(5*time.Second),
)
```

## Timeouts

Use `context.WithTimeout` - timeout applies to ALL attempts combined:

```go
ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
defer cancel()

result, err := pgxkit.Retry(ctx, func(ctx context.Context) (*User, error) {
    return fetchUser(ctx, userID)
}, pgxkit.WithMaxRetries(3))
```

## What Gets Retried

| Error Type | Retries? | Examples |
|------------|----------|----------|
| Network timeouts | Yes | dial timeout, read timeout |
| Connection failures | Yes | connection refused, connection reset |
| PostgreSQL connection errors | Yes | 08000, 08003, 08006 |
| Server shutdown | Yes | 57P01, 57P02, 57P03 |
| Serialization/deadlock | Yes | 40001, 40P01 |
| Context cancellation | No | context canceled |
| No rows found | No | pgx.ErrNoRows |
| Constraint violations | No | unique_violation, foreign_key_violation |

## IsRetryableError

Check if an error would be retried:

```go
if pgxkit.IsRetryableError(err) {
    log.Println("Transient error - would retry")
} else {
    log.Println("Permanent error - would not retry")
}
```

## When to Use Retry

✓ **Good candidates:**
- Background jobs
- Batch processes
- Health checks
- Non-interactive operations

✗ **Poor candidates:**
- User-facing HTTP handlers (use timeout instead)
- Operations inside transactions
- Idempotency-sensitive mutations without safeguards

## Structured Errors

```go
// Not found
var notFoundErr *pgxkit.NotFoundError
if errors.As(err, &notFoundErr) {
    return http.StatusNotFound
}

// Database operation failure
var dbErr *pgxkit.DatabaseError
if errors.As(err, &dbErr) {
    log.Printf("Operation %s failed: %v", dbErr.Operation, dbErr.Err)
}

// Validation failure
var valErr *pgxkit.ValidationError
if errors.As(err, &valErr) {
    log.Printf("Field %s: %s", valErr.Field, valErr.Reason)
}
```

### Error Constructors

```go
pgxkit.NewNotFoundError("User", userID)
pgxkit.NewDatabaseError("Order", "query", originalErr)
pgxkit.NewValidationError("User", "create", "email", "invalid format", nil)
```

## Common Patterns

### HTTP Handler with Timeout

```go
func GetUserHandler(db *pgxkit.DB) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
        defer cancel()

        user, err := pgxkit.Retry(ctx, func(ctx context.Context) (*User, error) {
            return fetchUser(ctx, db, userID)
        })

        if err != nil {
            if errors.Is(err, context.DeadlineExceeded) {
                http.Error(w, "request timeout", http.StatusGatewayTimeout)
                return
            }
            var notFound *pgxkit.NotFoundError
            if errors.As(err, &notFound) {
                http.Error(w, "user not found", http.StatusNotFound)
                return
            }
            http.Error(w, "internal error", http.StatusInternalServerError)
            return
        }

        json.NewEncoder(w).Encode(user)
    }
}
```

### Background Job with Retry

```go
func ProcessOrders(ctx context.Context, db *pgxkit.DB) error {
    return pgxkit.RetryOperation(ctx, func(ctx context.Context) error {
        rows, err := db.Query(ctx, "SELECT id FROM orders WHERE status = 'pending'")
        if err != nil {
            return err
        }
        defer rows.Close()

        for rows.Next() {
            var orderID int64
            if err := rows.Scan(&orderID); err != nil {
                return err
            }
            if err := processOrder(ctx, db, orderID); err != nil {
                return err
            }
        }
        return rows.Err()
    }, pgxkit.WithMaxRetries(5), pgxkit.WithMaxDelay(5*time.Second))
}
```

### Handling Duplicate Key Violations

```go
func CreateUser(ctx context.Context, db *pgxkit.DB, user *User) error {
    _, err := db.Exec(ctx, `
        INSERT INTO users (email, name) VALUES ($1, $2)`,
        user.Email, user.Name,
    )

    if err != nil {
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) && pgErr.Code == "23505" {
            return pgxkit.NewValidationError("User", "create", "email", "already exists", err)
        }
        return pgxkit.NewDatabaseError("User", "create", err)
    }
    return nil
}
```
