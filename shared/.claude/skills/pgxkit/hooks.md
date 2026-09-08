# pgxkit Hooks and Observability

Hooks for logging, metrics, tracing, and health checks.

**See also:** core.md (connection setup), testing.md (test cleanup hooks)

**Critical:** Hooks are configured via `ConnectOption` functions passed to `Connect()`.

## Hook Signature

```go
type HookFunc func(ctx context.Context, sql string, args []interface{}, tag pgconn.CommandTag, operationErr error) error
```

`tag` carries the real `pgconn.CommandTag` only on `AfterOperation` for Exec — pgx fills the tag after the statement runs. Everywhere else (every before-hook, `AfterOperation` on Query, transaction hooks, shutdown) it's the zero value. Use `tag.String() != ""` or check the SQL prefix to detect Exec.

## Basic Setup

```go
db := pgxkit.NewDB()
err := db.Connect(ctx, "",
    pgxkit.WithBeforeOperation(loggingHook),
    pgxkit.WithAfterOperation(metricsHook),
)
if err != nil {
    log.Fatal(err)
}
```

**Available hook options:**
- `WithBeforeOperation(fn HookFunc)`
- `WithAfterOperation(fn HookFunc)`
- `WithBeforeTransaction(fn HookFunc)`
- `WithAfterTransaction(fn HookFunc)`
- `WithOnShutdown(fn HookFunc)`

## Hook Types

| Type | When | sql param | tag | operationErr | If hook returns error |
|------|------|-----------|-----|--------------|----------------------|
| `BeforeOperation` | Before query/exec (incl. inside `*Tx`) | SQL statement | zero | always nil | Op aborted, hook error returned |
| `AfterOperation` | After query/exec (incl. inside `*Tx`) | SQL statement | real on Exec, zero on Query | op error or nil | If op succeeded: hook error returned. If op failed: op error returned |
| `BeforeTransaction` | Before BeginTx | empty | zero | always nil | Transaction aborted |
| `AfterTransaction` | After commit/rollback | `TxCommit` or `TxRollback` | zero | tx error or nil | Error propagated via `errors.Join` |
| `OnShutdown` | During Shutdown | empty | zero | always nil | Logged |

**`*Tx` operations fire `BeforeOperation`/`AfterOperation` too** — hooks see in-transaction queries through the same path as direct `*DB` calls.

**Execution order:** Sequential in registration order. Keep hooks fast.

**AfterTransaction notes:**
- Receives `pgxkit.TxCommit` ("TX:COMMIT") or `pgxkit.TxRollback` ("TX:ROLLBACK") as the `sql` parameter.
- Also fires when `BeginTx` fails (with empty `sql` and the begin error).
- Hook errors are combined with operation errors using `errors.Join`.

## Logging Hook

```go
err := db.Connect(ctx, "",
    pgxkit.WithBeforeOperation(func(ctx context.Context, sql string, args []interface{}, _ pgconn.CommandTag, _ error) error {
        log.Printf("Executing: %s", sql)
        return nil
    }),
)
```

## Metrics Hook (with rows-affected for Exec)

```go
err := db.Connect(ctx, "",
    pgxkit.WithAfterOperation(func(ctx context.Context, sql string, args []interface{}, tag pgconn.CommandTag, opErr error) error {
        if opErr != nil {
            metrics.IncrementCounter("db.errors")
            return nil
        }
        metrics.IncrementCounter("db.queries")
        if tag.String() != "" { // Exec — tag is empty for Query at this point
            metrics.AddCounter("db.rows_affected", float64(tag.RowsAffected()))
        }
        return nil
    }),
)
```

## OpenTelemetry Tracing Hook

```go
import "go.opentelemetry.io/otel/trace"
import "go.opentelemetry.io/otel/attribute"

err := db.Connect(ctx, "",
    pgxkit.WithBeforeOperation(func(ctx context.Context, sql string, args []interface{}, _ pgconn.CommandTag, _ error) error {
        span := trace.SpanFromContext(ctx)
        if span.IsRecording() {
            span.SetAttributes(
                attribute.String("db.system", "postgresql"),
                attribute.String("db.statement", sql),
            )
        }
        return nil
    }),
)
```

## Transaction Outcome Hook

```go
err := db.Connect(ctx, "",
    pgxkit.WithAfterTransaction(func(ctx context.Context, sql string, args []interface{}, _ pgconn.CommandTag, opErr error) error {
        switch sql {
        case pgxkit.TxCommit:
            if opErr == nil {
                metrics.IncrementCounter("db.tx.commits")
            } else {
                metrics.IncrementCounter("db.tx.commit_errors")
            }
        case pgxkit.TxRollback:
            metrics.IncrementCounter("db.tx.rollbacks")
        }
        return nil
    }),
)
```

## Connection-Level Hooks

```go
err := db.Connect(ctx, "",
    pgxkit.WithOnConnect(func(conn *pgx.Conn) error {
        _, err := conn.Exec(context.Background(), "SET application_name = 'myapp'")
        return err
    }),
    pgxkit.WithOnAcquire(func(ctx context.Context, conn *pgx.Conn) error {
        return conn.Ping(ctx)
    }),
)
```

**Available connection hook options:**
- `WithOnConnect(fn func(*pgx.Conn) error)` - called when new connection established
- `WithOnDisconnect(fn func(*pgx.Conn))` - called when connection closed
- `WithOnAcquire(fn func(context.Context, *pgx.Conn) error)` - called when connection acquired from pool
- `WithOnRelease(fn func(*pgx.Conn))` - called when connection released back to pool

## Health Checks

```go
db.HealthCheck(ctx) error         // Ping database, returns error
db.IsReady(ctx) bool              // Returns true if healthy

db.Stats() *pgxpool.Stat          // Write pool statistics
db.ReadStats() *pgxpool.Stat      // Read pool statistics
```

### HTTP Health Endpoint

```go
func HealthHandler(db *pgxkit.DB) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        if !db.IsReady(r.Context()) {
            http.Error(w, "database unavailable", http.StatusServiceUnavailable)
            return
        }
        w.WriteHeader(http.StatusOK)
    }
}
```

### Pool Exhaustion Detection

```go
func checkPoolHealth(db *pgxkit.DB) {
    stats := db.Stats()
    utilization := float64(stats.AcquiredConns()) / float64(stats.MaxConns())
    if utilization > 0.8 {
        log.Printf("WARNING: Pool at %.0f%% capacity", utilization*100)
    }
}
```

## Graceful Shutdown

```go
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

// Shutdown behavior:
// 1. Marks DB as shutting down (new operations fail immediately)
// 2. Waits for active operations to complete (respects context timeout)
// 3. Executes OnShutdown hooks
// 4. Closes connection pools
// Note: If timeout exceeded, proceeds with shutdown anyway
err := db.Shutdown(ctx)
```

## Note on Hook Timing

Hooks are configured at connection time via `ConnectOption` functions. They cannot be added after `Connect()` is called.

```go
db := pgxkit.NewDB()
err := db.Connect(ctx, "",
    pgxkit.WithBeforeOperation(myHook),  // Configure hooks here
    pgxkit.WithAfterOperation(metricsHook),
)
```
