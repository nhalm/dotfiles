# pgxkit Core

Connections, queries, and transactions.

**See also:** retry.md (Retry, RetryOperation), hooks.md (observability)

```go
import (
    "github.com/nhalm/pgxkit/v2"
    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgconn"
)
```

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
```

## Choosing Query Methods

```
Need consistency after a write in same request?
  → Use Query() / QueryRow() (write pool)

Read-only analytics or dashboards?
  → Use ReadQuery() / ReadQueryRow() (read pool, may have lag)

User-facing with tight latency budget?
  → Use context.WithTimeout(ctx, 5*time.Second)

Background job that can retry on failure?
  → Use Retry() / RetryOperation() wrappers

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
| Transactions | `db.BeginTx()` | Write | `*Tx, error` |

## Core Types

```go
type DB struct { /* wraps pgxpool.Pool for read/write splitting */ }

func NewDB() *DB
func (db *DB) Connect(ctx context.Context, dsn string) error
func (db *DB) ConnectReadWrite(ctx context.Context, readDSN, writeDSN string) error
func (db *DB) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
func (db *DB) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
func (db *DB) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
func (db *DB) BeginTx(ctx context.Context, txOptions pgx.TxOptions) (*Tx, error)
func (db *DB) Shutdown(ctx context.Context) error

func GetDSN() string  // Build DSN from POSTGRES_* env vars
```

## Executor Interface

Both `*DB` and `*Tx` implement `Executor`, enabling functions that work with either:

```go
type Executor interface {
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}
```

**Pattern:** Write repository functions accepting `Executor`:

```go
func CreateUser(ctx context.Context, exec pgxkit.Executor, name string) (int64, error) {
    var id int64
    err := exec.QueryRow(ctx,
        "INSERT INTO users (name) VALUES ($1) RETURNING id", name,
    ).Scan(&id)
    return id, err
}

// Works with *DB (no transaction)
id, err := CreateUser(ctx, db, "Alice")

// Works with *Tx (in transaction)
tx, _ := db.BeginTx(ctx, pgx.TxOptions{})
defer tx.Rollback(ctx)
id, err := CreateUser(ctx, tx, "Bob")
tx.Commit(ctx)
```

## Tx Type

`*Tx` wraps `pgx.Tx` with finalization tracking and hook integration.

| Method | Description |
|--------|-------------|
| `Query(ctx, sql, args...)` | Execute query (returns `ErrTxFinalized` if finalized) |
| `QueryRow(ctx, sql, args...)` | Execute single-row query |
| `Exec(ctx, sql, args...)` | Execute statement |
| `Commit(ctx)` | Commit transaction, fire `AfterTransaction` hook with `TxCommit` |
| `Rollback(ctx)` | Rollback transaction, fire `AfterTransaction` hook with `TxRollback` |
| `IsFinalized()` | Returns true if already committed/rolled back |

**Constants:**
- `pgxkit.TxCommit = "TX:COMMIT"` - passed to `AfterTransaction` hook on commit
- `pgxkit.TxRollback = "TX:ROLLBACK"` - passed to `AfterTransaction` hook on rollback
- `pgxkit.ErrTxFinalized` - returned when operating on finalized transaction

**Finalization behavior:** `Commit()` and `Rollback()` are safe to call multiple times - subsequent calls are no-ops. This enables the `defer tx.Rollback(ctx)` pattern.

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

// BAD: Operating on finalized transaction
tx, _ := db.BeginTx(ctx, pgx.TxOptions{})
tx.Commit(ctx)
_, err := tx.Exec(ctx, "INSERT ...")  // Returns ErrTxFinalized!

// GOOD: Check finalization if uncertain
if tx.IsFinalized() {
    return errors.New("transaction already completed")
}
_, err := tx.Exec(ctx, "INSERT ...")
```
