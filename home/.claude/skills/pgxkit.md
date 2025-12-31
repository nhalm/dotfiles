# pgxkit

Production-ready PostgreSQL toolkit for Go wrapping pgx/v5. Safe-by-default connection management with read/write pool splitting, extensible hooks for observability, and comprehensive testing utilities.

```go
import (
    "github.com/nhalm/pgxkit"
    "github.com/jackc/pgx/v5"           // For pgx.Rows, pgx.Row, pgx.Tx, pgx.TxOptions, pgx.ErrNoRows
    "github.com/jackc/pgx/v5/pgconn"    // For pgconn.CommandTag
    "github.com/jackc/pgx/v5/pgtype"    // For type conversions
    "github.com/jackc/pgx/v5/pgxpool"   // For pgxpool.Stat
    "github.com/google/uuid"            // For UUID conversions
)
```

## When to Trigger

Activate when you see:
- `import "github.com/nhalm/pgxkit"` in Go files
- `pgxkit.NewDB()` or `pgxkit.NewTestDB()` calls
- go.mod contains `github.com/nhalm/pgxkit` dependency
- User explicitly requests pgxkit usage
- Discussion of PostgreSQL read/write splitting or replica lag
- NULL handling with pgtype in Go

Do NOT trigger for:
- Standard library `database/sql` usage
- Direct `pgx/v5` usage without pgxkit wrapper
- Other database libraries (sqlx, gorm, ent, etc.)
- General SQL writing without pgxkit context

## Critical Rules

1. **Never use `ReadQuery*` for data just written** - replica lag (1-5s typical) causes stale reads
2. **Always defer `db.Shutdown(ctx)`** after successful connection
3. **Always defer `rows.Close()` AND check `rows.Err()`** after iteration
4. **Always defer `tx.Rollback(ctx)`** in transactions - safe even after commit
5. **Add hooks BEFORE `Connect()`** - hooks configure pool creation
6. **Use `RequireDB(t)` in tests** to gracefully skip when DB unavailable
7. **Transaction handles (`pgx.Tx`) are NOT concurrent-safe** - use one goroutine per transaction

## Core Philosophy

- **Safety First**: All operations default to write pool for consistency
- **Explicit Optimization**: Use `ReadQuery()` methods only when replica lag is acceptable
- **Tool Agnostic**: Works with raw pgx, sqlc, or Skimatik
- **Concurrent Safe**: `*DB` is safe for concurrent use across goroutines (but `pgx.Tx` handles are NOT)

## Quick Reference

```go
// Setup
ctx := context.Background()
db := pgxkit.NewDB()
if err := db.Connect(ctx, ""); err != nil {  // Uses POSTGRES_* env vars
    log.Fatal(err)
}
defer db.Shutdown(ctx)

// Query multiple rows
rows, err := db.Query(ctx, "SELECT id, name FROM users WHERE active = $1", true)
if err != nil {
    return fmt.Errorf("query failed: %w", err)
}
defer rows.Close()

for rows.Next() {
    var id int64
    var name string
    if err := rows.Scan(&id, &name); err != nil {
        return fmt.Errorf("scan failed: %w", err)
    }
    fmt.Printf("%d: %s\n", id, name)
}
if err := rows.Err(); err != nil {  // Always check after loop
    return fmt.Errorf("iteration error: %w", err)
}

// Query single row
var name string
err := db.QueryRow(ctx, "SELECT name FROM users WHERE id = $1", userID).Scan(&name)
if err != nil {
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, ErrNotFound
    }
    return nil, err
}

// Transaction with proper cleanup
tx, err := db.BeginTx(ctx, pgx.TxOptions{})
if err != nil {
    return err
}
defer tx.Rollback(ctx)  // Safe even after commit

if _, err := tx.Exec(ctx, "UPDATE accounts SET balance = balance - $1 WHERE id = $2", amount, fromID); err != nil {
    return err  // Rollback via defer
}
if _, err := tx.Exec(ctx, "UPDATE accounts SET balance = balance + $1 WHERE id = $2", amount, toID); err != nil {
    return err  // Rollback via defer
}

return tx.Commit(ctx)

// Testing
testDB := pgxkit.RequireDB(t)
defer testDB.Shutdown(ctx)
```

## Choosing Query Methods

```
Need consistency after a write in same request?
  → Use Query() / QueryRow() (write pool)

Read-only analytics or dashboards?
  → Use ReadQuery() / ReadQueryRow() (read pool, may have lag)

User-facing with tight latency budget?
  → Use WithTimeout(ctx, 5*time.Second, fn)

Background job that can retry on failure?
  → Use ExecWithRetry() / QueryWithRetry()

Financial transaction or multi-step mutation?
  → Use BeginTx() with deferred Rollback()
```

| Operation | Method | Pool | Returns |
|-----------|--------|------|---------|
| INSERT/UPDATE/DELETE | `db.Exec()` | Write | `pgconn.CommandTag, error` |
| SELECT (safe) | `db.Query()` | Write | `pgx.Rows, error` |
| SELECT (optimized) | `db.ReadQuery()` | Read | `pgx.Rows, error` |
| Single row (safe) | `db.QueryRow()` | Write | `pgx.Row` |
| Single row (optimized) | `db.ReadQueryRow()` | Read | `pgx.Row` |
| Transactions | `db.BeginTx()` | Write | `pgx.Tx, error` |

## Core Types

```go
type DB struct { /* wraps pgxpool.Pool for read/write splitting */ }

func NewDB() *DB
func (db *DB) Connect(ctx context.Context, dsn string) error
func (db *DB) ConnectReadWrite(ctx context.Context, readDSN, writeDSN string) error
func (db *DB) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
func (db *DB) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
func (db *DB) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
func (db *DB) BeginTx(ctx context.Context, txOptions pgx.TxOptions) (pgx.Tx, error)
func (db *DB) Shutdown(ctx context.Context) error

func GetDSN() string  // Build DSN from POSTGRES_* env vars
```

## Connection Patterns

### Single Pool (Most Apps)

```go
ctx := context.Background()
db := pgxkit.NewDB()

// Option 1: Use POSTGRES_* environment variables
if err := db.Connect(ctx, ""); err != nil {
    log.Fatalf("connection failed: %v", err)
}
defer db.Shutdown(ctx)

// Option 2: Explicit DSN
if err := db.Connect(ctx, "postgres://user:pass@localhost:5432/mydb?sslmode=disable"); err != nil {
    log.Fatalf("connection failed: %v", err)
}
defer db.Shutdown(ctx)
```

**Environment variables** (used when DSN is empty string):
| Variable | Default |
|----------|---------|
| `POSTGRES_HOST` | localhost |
| `POSTGRES_PORT` | 5432 |
| `POSTGRES_USER` | postgres |
| `POSTGRES_PASSWORD` | (none) |
| `POSTGRES_DB` | postgres |
| `POSTGRES_SSLMODE` | disable |

### Read/Write Split

```go
db := pgxkit.NewDB()
err := db.ConnectReadWrite(ctx,
    "postgres://user@read-replica:5432/db",  // read pool (replicas)
    "postgres://user@primary:5432/db")       // write pool (primary)
if err != nil {
    log.Fatalf("connection failed: %v", err)
}
defer db.Shutdown(ctx)
```

**Note:** If read replica is unavailable, `ReadQuery*` calls fail immediately. There is no automatic fallback to write pool.

### Pool Sizing Guidance

Default pool size is `4 × numCPU`. Each connection uses ~10MB memory.

| Environment | Recommended MaxConns |
|-------------|---------------------|
| Local dev | 2-4 |
| Kubernetes pod (1 CPU) | 4-8 |
| API server (4 CPU) | 16-32 |
| High-throughput (8+ CPU) | 4 × numCPU |

## Retry and Timeout

```go
// RetryConfig controls retry behavior with exponential backoff
type RetryConfig struct {
    MaxRetries int           // Maximum retry attempts (default: 3)
    BaseDelay  time.Duration // Initial delay (default: 100ms)
    MaxDelay   time.Duration // Delay cap (default: 1s)
    Multiplier float64       // Backoff multiplier (default: 2.0)
}

// Default: 3 retries, 100ms base delay, 1s max delay, 2x backoff
// Timing: 100ms → 200ms → 400ms (capped at MaxDelay)
config := pgxkit.DefaultRetryConfig()

// Customize if needed
config.MaxRetries = 5
config.MaxDelay = 5 * time.Second

// All retry variants
db.ExecWithRetry(ctx, config, sql, args...)
db.QueryWithRetry(ctx, config, sql, args...)
db.QueryRowWithRetry(ctx, config, sql, args...)
db.ReadQueryWithRetry(ctx, config, sql, args...)
db.ReadQueryRowWithRetry(ctx, config, sql, args...)
db.BeginTxWithRetry(ctx, config, txOptions)

// Generic retry for custom operations
err := pgxkit.RetryOperation(ctx, config, func(ctx context.Context) error {
    return someComplexOperation(ctx)
})

// Timeout wrapper (user-facing requests)
result, err := pgxkit.WithTimeout(ctx, 5*time.Second, func(ctx context.Context) (*User, error) {
    return fetchUser(ctx)  // Your function
})

// Combined timeout + retry (background jobs)
result, err := pgxkit.WithTimeoutAndRetry(ctx, 5*time.Second, config, func(ctx context.Context) (*User, error) {
    return fetchUser(ctx)
})
```

**Will retry:** connection errors (08xxx), serialization failures (40001), deadlocks (40P01), network errors

**Will NOT retry:** context cancellation, `pgx.ErrNoRows`, validation errors

### When to Use Retry

✓ Background jobs, batch processes, health checks
✗ User-facing HTTP handlers (use timeout instead), operations inside transactions

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

// Constructors
pgxkit.NewNotFoundError("User", userID)
pgxkit.NewDatabaseError("Order", "query", originalErr)
pgxkit.NewValidationError("User", "create", "email", "invalid format", nil)
```

## Type Conversions

Convert between Go types and pgtype for NULL handling.

**Pattern:** `ToPgx*(input) → pgtype.T` and `FromPgx*(pgtype.T) → output`

```go
// Nullable (pointer) variants - for columns that allow NULL
ToPgxText(*string) → pgtype.Text           | FromPgxText(pgtype.Text) → *string
ToPgxInt8(*int64) → pgtype.Int8            | FromPgxInt8(pgtype.Int8) → *int64
ToPgxInt4(*int32) → pgtype.Int4            | FromPgxInt4(pgtype.Int4) → *int32
ToPgxInt2(*int16) → pgtype.Int2            | FromPgxInt2(pgtype.Int2) → *int16
ToPgxBool(*bool) → pgtype.Bool             | FromPgxBool(pgtype.Bool) → *bool
ToPgxFloat8(*float64) → pgtype.Float8      | FromPgxFloat8(pgtype.Float8) → *float64
ToPgxNumeric(*float64) → pgtype.Numeric    | FromPgxNumeric(pgtype.Numeric) → *float64
ToPgxTimestamp(*time.Time) → pgtype.Timestamp | FromPgxTimestamp(pgtype.Timestamp) → *time.Time
ToPgxTimestamptz(*time.Time) → pgtype.Timestamptz | FromPgxTimestamptz(pgtype.Timestamptz) → time.Time
                                           | FromPgxTimestamptzPtr(pgtype.Timestamptz) → *time.Time
ToPgxDate(*time.Time) → pgtype.Date        | FromPgxDate(pgtype.Date) → *time.Time
ToPgxTime(*time.Time) → pgtype.Time        | FromPgxTime(pgtype.Time) → *time.Time
ToPgxUUID(uuid.UUID) → pgtype.UUID         | FromPgxUUID(pgtype.UUID) → uuid.UUID
ToPgxUUIDFromPtr(*uuid.UUID) → pgtype.UUID | FromPgxUUIDToPtr(pgtype.UUID) → *uuid.UUID

// Non-null (value) variants - for NOT NULL columns
ToPgxTextFromString(string) → pgtype.Text  | FromPgxTextToString(pgtype.Text) → string
ToPgxBoolFromBool(bool) → pgtype.Bool      | FromPgxBoolToBool(pgtype.Bool) → bool
ToPgxInt4FromInt(*int) → pgtype.Int4       | FromPgxInt4ToInt(pgtype.Int4) → *int

// Arrays
ToPgxTextArray([]string) → pgtype.Array[pgtype.Text] | FromPgxTextArray(...) → []string
ToPgxInt8Array([]int64) → pgtype.Array[pgtype.Int8]  | FromPgxInt8Array(...) → []int64
```

### Usage Example

```go
// Insert with type conversion
name := "Alice"
createdAt := time.Now()

_, err := db.Exec(ctx, `
    INSERT INTO users (name, created_at) VALUES ($1, $2)`,
    pgxkit.ToPgxTextFromString(name),
    pgxkit.ToPgxTimestamptz(&createdAt),
)

// Scan with type conversion
var nameCol pgtype.Text
var createdCol pgtype.Timestamptz
err := db.QueryRow(ctx, "SELECT name, created_at FROM users WHERE id = $1", id).Scan(&nameCol, &createdCol)

userName := pgxkit.FromPgxTextToString(nameCol)
userCreated := pgxkit.FromPgxTimestamptz(createdCol)
```

## Testing

### RequireDB (Recommended)

Use for most tests. Automatically skips if database unavailable.

```go
func TestUserCreate(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.RequireDB(t)  // Skips test if TEST_DATABASE_URL not set
    defer testDB.Shutdown(ctx)

    _, err := testDB.Exec(ctx, "INSERT INTO users (name) VALUES ($1)", "test")
    require.NoError(t, err)
}
```

Requires: `export TEST_DATABASE_URL="postgres://user:pass@localhost:5432/testdb"`

### Manual Setup with Cleanup

Use when you need custom cleanup logic.

```go
func TestWithCleanup(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.NewTestDB()

    if err := testDB.Connect(ctx, os.Getenv("TEST_DATABASE_URL")); err != nil {
        t.Skip("Test database not available")
    }
    defer testDB.Shutdown(ctx)

    testDB.Setup()       // Verifies connection is working
    defer testDB.Clean() // Runs registered cleanup (typically TRUNCATE)

    // Your test code
}
```

### Golden Testing (Query Plan Regression)

Captures EXPLAIN plans for SELECT queries and compares against baseline.

```go
func TestQueryPerformance(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.RequireDB(t)
    defer testDB.Shutdown(ctx)

    db := testDB.EnableGolden("TestQueryPerformance")

    rows, err := db.Query(ctx, "SELECT * FROM users WHERE active = $1", true)
    require.NoError(t, err)
    defer rows.Close()

    db.AssertGolden(t, "TestQueryPerformance")
}
```

**Golden file workflow:**
1. First run: Creates `testdata/golden/TestName.json`
2. Copy to baseline: `cp testdata/golden/TestName.json testdata/golden/TestName.json.baseline`
3. Subsequent runs: Compares against `.json.baseline`
4. To update after intentional changes: repeat step 2

```go
pgxkit.CleanupGolden("TestQueryPerformance")  // Remove golden files
```

**Note:** Golden testing only captures SELECT queries. EXPLAIN queries are automatically skipped.

## Hook System

```go
// Hook signature (universal for all operation hooks)
type HookFunc func(ctx context.Context, sql string, args []interface{}, operationErr error) error
```

**Important:** Add hooks BEFORE calling `Connect()`.

```go
db := pgxkit.NewDB()

// Logging (BeforeOperation: operationErr is always nil)
db.AddHook(pgxkit.BeforeOperation, func(ctx context.Context, sql string, args []interface{}, _ error) error {
    log.Printf("Executing: %s", sql)
    return nil
})

// Metrics (AfterOperation: operationErr contains query result error)
db.AddHook(pgxkit.AfterOperation, func(ctx context.Context, sql string, args []interface{}, err error) error {
    if err != nil {
        metrics.IncrementCounter("db.errors")
    }
    return nil
})

// Then connect
if err := db.Connect(ctx, ""); err != nil {
    log.Fatal(err)
}
```

**Hook types:**
| Type | When | operationErr | If hook returns error |
|------|------|--------------|----------------------|
| `BeforeOperation` | Before query/exec | always nil | Query aborted, hook error returned |
| `AfterOperation` | After query/exec | query error or nil | If query succeeded: hook error returned. If query failed: query error returned (hook error ignored) |
| `BeforeTransaction` | Before BeginTx | always nil | Transaction aborted |
| `AfterTransaction` | After commit/rollback | transaction error or nil | Logged |
| `OnShutdown` | During Shutdown | always nil | Logged |

**Execution order:** Sequential in registration order. Keep hooks fast to avoid latency.

### Connection-Level Hooks

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

### Pool Exhaustion Debugging

```go
stats := db.Stats()
utilization := float64(stats.AcquiredConns()) / float64(stats.MaxConns())
if utilization > 0.8 {
    log.Printf("WARNING: Pool at %.0f%% capacity", utilization*100)
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

## Common Pitfalls

```go
// BAD: ReadQuery after mutation - replica lag causes stale/missing data
db.Exec(ctx, "INSERT INTO users (name) VALUES ($1)", "Alice")
rows, _ := db.ReadQuery(ctx, "SELECT * FROM users WHERE name = $1", "Alice") // May return empty!

// GOOD: Use write pool for read-after-write consistency
db.Exec(ctx, "INSERT INTO users (name) VALUES ($1)", "Alice")
rows, _ := db.Query(ctx, "SELECT * FROM users WHERE name = $1", "Alice") // Consistent

// BAD: Forgetting rows.Err() check (silent data corruption)
rows, _ := db.Query(ctx, "SELECT * FROM users")
defer rows.Close()
for rows.Next() {
    rows.Scan(&user)
}
// Missing rows.Err() check!

// GOOD: Always check rows.Err() after iteration
rows, err := db.Query(ctx, "SELECT * FROM users")
if err != nil { return err }
defer rows.Close()
for rows.Next() {
    if err := rows.Scan(&user); err != nil { return err }
}
if err := rows.Err(); err != nil { return err }  // Critical!

// BAD: Transaction without deferred rollback
tx, _ := db.BeginTx(ctx, pgx.TxOptions{})
tx.Exec(ctx, "UPDATE ...")
if err != nil {
    tx.Rollback(ctx)  // Easy to forget on all error paths!
    return err
}
tx.Commit(ctx)

// GOOD: Always defer rollback (safe even after commit)
tx, err := db.BeginTx(ctx, pgx.TxOptions{})
if err != nil { return err }
defer tx.Rollback(ctx)  // No-op after successful commit

if _, err := tx.Exec(ctx, "UPDATE ..."); err != nil {
    return err  // Rollback via defer
}
return tx.Commit(ctx)

// BAD: Adding hooks after Connect
db := pgxkit.NewDB()
db.Connect(ctx, "")
db.AddHook(pgxkit.BeforeOperation, myHook) // Too late!

// GOOD: Add hooks before Connect
db := pgxkit.NewDB()
db.AddHook(pgxkit.BeforeOperation, myHook)
db.Connect(ctx, "")
```
