# pgxkit Hooks and Observability

Hooks for logging, metrics, tracing, and health checks.

**See also:** core.md (connection setup), testing.md (test cleanup hooks)

**Critical:** Add hooks BEFORE calling `Connect()`.

## Hook Signature

```go
type HookFunc func(ctx context.Context, sql string, args []interface{}, operationErr error) error
```

## Basic Setup

```go
db := pgxkit.NewDB()

// Add hooks BEFORE Connect
db.AddHook(pgxkit.BeforeOperation, loggingHook)
db.AddHook(pgxkit.AfterOperation, metricsHook)

// Then connect
if err := db.Connect(ctx, ""); err != nil {
    log.Fatal(err)
}
```

## Hook Types

| Type | When | operationErr | If hook returns error |
|------|------|--------------|----------------------|
| `BeforeOperation` | Before query/exec | always nil | Query aborted, hook error returned |
| `AfterOperation` | After query/exec | query error or nil | If query succeeded: hook error returned. If query failed: query error returned |
| `BeforeTransaction` | Before BeginTx | always nil | Transaction aborted |
| `AfterTransaction` | After commit/rollback | tx error or nil | Logged |
| `OnShutdown` | During Shutdown | always nil | Logged |

**Execution order:** Sequential in registration order. Keep hooks fast.

## Logging Hook

```go
db.AddHook(pgxkit.BeforeOperation, func(ctx context.Context, sql string, args []interface{}, _ error) error {
    log.Printf("Executing: %s", sql)
    return nil
})
```

## Metrics Hook

```go
db.AddHook(pgxkit.AfterOperation, func(ctx context.Context, sql string, args []interface{}, err error) error {
    if err != nil {
        metrics.IncrementCounter("db.errors")
    } else {
        metrics.IncrementCounter("db.queries")
    }
    return nil
})
```

## OpenTelemetry Tracing Hook

```go
import "go.opentelemetry.io/otel/trace"
import "go.opentelemetry.io/otel/attribute"

db.AddHook(pgxkit.BeforeOperation, func(ctx context.Context, sql string, args []interface{}, _ error) error {
    span := trace.SpanFromContext(ctx)
    if span.IsRecording() {
        span.SetAttributes(
            attribute.String("db.system", "postgresql"),
            attribute.String("db.statement", sql),
        )
    }
    return nil
})
```

## Slow Query Detection

```go
type queryStartKey struct{}

db.AddHook(pgxkit.BeforeOperation, func(ctx context.Context, sql string, args []interface{}, _ error) error {
    return context.WithValue(ctx, queryStartKey{}, time.Now())
})

db.AddHook(pgxkit.AfterOperation, func(ctx context.Context, sql string, args []interface{}, err error) error {
    if start, ok := ctx.Value(queryStartKey{}).(time.Time); ok {
        duration := time.Since(start)
        if duration > 100*time.Millisecond {
            log.Printf("SLOW QUERY [%v]: %s", duration, sql)
        }
    }
    return nil
})
```

## Connection-Level Hooks

```go
db.AddConnectionHook("OnConnect", func(conn *pgx.Conn) error {
    _, err := conn.Exec(context.Background(), "SET application_name = 'myapp'")
    return err
})

// Helper functions
pgxkit.ValidationHook()  // Validates connection on acquire
pgxkit.SetupHook()       // Custom setup on new connections
pgxkit.CombineHooks()    // Combine multiple hooks
```

## Health Checks

```go
db.HealthCheck(ctx) error         // Ping database, returns error
db.IsReady(ctx) bool              // Returns true if healthy

db.Stats() *pgxpool.Stat          // Write pool statistics
db.ReadStats() *pgxpool.Stat      // Read pool statistics
db.WriteStats() *pgxpool.Stat     // Alias for Stats()
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

## Common Pitfall

```go
// BAD: Adding hooks after Connect
db := pgxkit.NewDB()
db.Connect(ctx, "")
db.AddHook(pgxkit.BeforeOperation, myHook) // Too late! Hooks ignored.

// GOOD: Add hooks before Connect
db := pgxkit.NewDB()
db.AddHook(pgxkit.BeforeOperation, myHook)
db.Connect(ctx, "")
```
