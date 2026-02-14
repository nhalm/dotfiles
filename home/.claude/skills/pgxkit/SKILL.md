# pgxkit

Production-ready PostgreSQL toolkit for Go wrapping pgx/v5. Safe-by-default connection management with read/write pool splitting, extensible hooks for observability, and comprehensive testing utilities.

## When to Trigger

Activate when you see:
- `import "github.com/nhalm/pgxkit/v2"` in Go files
- `pgxkit.NewDB()` or `pgxkit.NewTestDB()` calls
- `db.ReadQuery()` or `db.ReadQueryRow()` calls
- `pgxkit.Executor` interface usage
- `db.BeginTx()` returning `*pgxkit.Tx`
- go.mod contains `github.com/nhalm/pgxkit/v2` dependency
- User explicitly requests pgxkit usage
- Debugging replica lag issues with pgxkit's read/write split
- NULL handling with pgxkit type converters (`ToPgx*`, `FromPgx*`)

Do NOT trigger for:
- Standard library `database/sql` usage
- Direct `pgx/v5` usage without pgxkit wrapper
- Other database libraries (sqlx, gorm, ent, etc.)
- General SQL writing without pgxkit context
- General PostgreSQL replication setup without pgxkit

## Critical Rules

1. **Never use `ReadQuery*` for data just written** - replica lag (1-5s typical) causes stale reads
2. **Always defer `db.Shutdown(ctx)`** after successful connection
3. **Always defer `rows.Close()` AND check `rows.Err()`** after iteration
4. **Always defer `tx.Rollback(ctx)`** in transactions - safe even after commit (no-op if already finalized)
5. **Add hooks BEFORE `Connect()`** - hooks configure pool creation
6. **Use `RequireDB(t)` in tests** to gracefully skip when DB unavailable
7. **`*Tx` is NOT concurrent-safe** - use one goroutine per transaction
8. **Check `ErrTxFinalized`** when operations might run on already-committed/rolled-back transactions
9. **Use `Executor` interface** for functions that should work with both `*DB` and `*Tx`

## Core Philosophy

- **Safety First**: All operations default to write pool for consistency
- **Explicit Optimization**: Use `ReadQuery()` methods only when replica lag is acceptable
- **Tool Agnostic**: Works with raw pgx, sqlc, or Skimatik
- **Concurrent Safe**: `*DB` is safe for concurrent use across goroutines (but `*Tx` handles are NOT)
- **Unified Interface**: `Executor` interface allows writing functions that work with both `*DB` and `*Tx`

## Skill Files

- `core.md` - Connections, queries, transactions, quick reference
- `testing.md` - RequireDB, TestDB, golden testing, test patterns
- `types.md` - Type conversions between Go and pgtype for NULL handling
- `hooks.md` - Hooks, observability, health checks, graceful shutdown
- `retry.md` - Retry logic, timeouts, error handling

## Troubleshooting Index

| Error/Symptom | File | Section |
|--------------|------|---------|
| "connection refused" | core.md | Environment Variables |
| Stale data after write | core.md | Common Pitfalls (replica lag) |
| rows iteration failed silently | core.md | Common Pitfalls (rows.Err) |
| `ErrTxFinalized` | core.md | Tx Type |
| "test database not available" | testing.md | Troubleshooting |
| nil pointer with NULL column | types.md | Nullable (Pointer) Variants |
| Hook not executing | hooks.md | Common Pitfall |
| AfterTransaction not receiving outcome | hooks.md | Transaction Hooks |
| Timeout exceeded | retry.md | Timeout Wrappers |
| Duplicate key violation | retry.md | Handling Duplicate Key Violations |

## Common Recipes

### Cursor Pagination with Timeout

```go
func GetUsers(ctx context.Context, db *pgxkit.DB, cursor *int64, limit int) ([]User, *int64, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    cursorVal := int64(0)
    if cursor != nil {
        cursorVal = *cursor
    }

    rows, err := db.ReadQuery(ctx,
        "SELECT id, name FROM users WHERE id > $1 ORDER BY id LIMIT $2",
        cursorVal, limit+1) // Fetch one extra to detect more pages
    if err != nil {
        return nil, nil, err
    }
    defer rows.Close()

    var users []User
    for rows.Next() {
        var u User
        if err := rows.Scan(&u.ID, &u.Name); err != nil {
            return nil, nil, err
        }
        users = append(users, u)
    }
    if err := rows.Err(); err != nil {
        return nil, nil, err
    }

    var nextCursor *int64
    if len(users) > limit {
        nextCursor = &users[limit].ID
        users = users[:limit]
    }
    return users, nextCursor, nil
}
```

### Upsert with RETURNING

```go
func UpsertUser(ctx context.Context, db *pgxkit.DB, email, name string) (*User, error) {
    var user User
    err := db.QueryRow(ctx, `
        INSERT INTO users (email, name, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (email) DO UPDATE SET
            name = EXCLUDED.name,
            updated_at = NOW()
        RETURNING id, email, name, created_at, updated_at`,
        email, name,
    ).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt, &user.UpdatedAt)
    if err != nil {
        return nil, pgxkit.NewDatabaseError("User", "upsert", err)
    }
    return &user, nil
}
```

### Batch Insert with Transaction

```go
func CreateUsers(ctx context.Context, db *pgxkit.DB, users []CreateUserRequest) error {
    tx, err := db.BeginTx(ctx, pgx.TxOptions{})
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    for _, u := range users {
        _, err := tx.Exec(ctx,
            "INSERT INTO users (email, name) VALUES ($1, $2)",
            pgxkit.ToPgxTextFromString(u.Email),
            pgxkit.ToPgxTextFromString(u.Name),
        )
        if err != nil {
            var pgErr *pgconn.PgError
            if errors.As(err, &pgErr) && pgErr.Code == "23505" {
                return pgxkit.NewValidationError("User", "create", "email", "already exists", err)
            }
            return pgxkit.NewDatabaseError("User", "create", err)
        }
    }

    return tx.Commit(ctx)
}
```

### HTTP Handler with Full Error Handling

See retry.md "HTTP Handler with Timeout" for complete pattern.
