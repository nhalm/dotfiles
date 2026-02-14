# pgxkit Hooks and Observability

Hooks for logging, metrics, tracing, and health checks.

**See also:** core.md (connection setup), testing.md (test cleanup hooks)

**Critical:** Hooks are configured via `ConnectOption` functions passed to `Connect()`.

## Hook Signature

```go
type HookFunc func(ctx context.Context, sql string, args []interface{}, operationErr error) error
```

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

| Type | When | sql param | operationErr | If hook returns error |
|------|------|-----------|--------------|----------------------|
| `BeforeOperation` | Before query/exec | SQL statement | always nil | Query aborted, hook error returned |
| `AfterOperation` | After query/exec | SQL statement | query error or nil | If query succeeded: hook error returned. If query failed: query error returned |
| `BeforeTransaction` | Before BeginTx | empty | always nil | Transaction aborted |
| `AfterTransaction` | After commit/rollback | `TxCommit` or `TxRollback` | tx error or nil | Error propagated via `errors.Join` |
| `OnShutdown` | During Shutdown | empty | always nil | Logged |

**Execution order:** Sequential in registration order. Keep hooks fast.

**AfterTransaction notes:**
- Receives `pgxkit.TxCommit` ("TX:COMMIT") or `pgxkit.TxRollback` ("TX:ROLLBACK") as the `sql` parameter
- Also fires when `BeginTx` fails (with empty `sql` and the begin error)
- Hook errors are combined with operation errors using `errors.Join`

## Logging Hook

```go
err := db.Connect(ctx, "",
    pgxkit.WithBeforeOperation(func(ctx context.Context, sql string, args []interface{}, _ error) error {
        log.Printf("Executing: %s", sql)
        return nil
    }),
)
```

## Metrics Hook

```go
err := db.Connect(ctx, "",
    pgxkit.WithAfterOperation(func(ctx context.Context, sql string, args []interface{}, err error) error {
        if err != nil {
            metrics.IncrementCounter("db.errors")
        } else {
            metrics.IncrementCounter("db.queries")
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
    pgxkit.WithBeforeOperation(func(ctx context.Context, sql string, args []interface{}, _ error) error {
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
