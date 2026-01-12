# pgxkit Testing

Test utilities for PostgreSQL integration tests.

**See also:** hooks.md (OnShutdown hooks), retry.md (RetryOperation for flaky environments)

## RequireDB (Recommended)

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

## Manual Setup with Cleanup

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

## Golden Testing (Query Plan Regression)

Captures EXPLAIN plans for SELECT queries and compares against baseline to detect query regressions.

**Use when:**
- Query performance is critical
- Schema changes might break optimization
- You want CI to catch N+1 or missing index problems

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
1. First run: Creates `testdata/golden/TestName.json` (auto-becomes baseline)
2. Subsequent runs: Compares against baseline
3. To update after intentional changes:
   ```bash
   cp testdata/golden/TestName.json testdata/golden/TestName.json.baseline
   ```

```go
pgxkit.CleanupGolden("TestQueryPerformance")  // Remove golden files
```

**Limitations:**
- Only captures SELECT queries (INSERT/UPDATE/DELETE silently skipped)
- EXPLAIN queries automatically skipped to avoid recursion

## Parallel Test Safety

Tests using `RequireDB` are safe for parallel execution - each gets its own context.

```go
func TestParallel(t *testing.T) {
    tests := []struct {
        name string
        // ...
    }{
        {"case1", /* ... */},
        {"case2", /* ... */},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()  // Safe with pgxkit
            ctx := context.Background()
            testDB := pgxkit.RequireDB(t)
            defer testDB.Shutdown(ctx)
            // Test code
        })
    }
}
```

## Test Data Isolation

Use transactions for test isolation when you can't truncate between tests:

```go
func TestWithTransaction(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.RequireDB(t)
    defer testDB.Shutdown(ctx)

    // Start transaction that will be rolled back
    tx, err := testDB.BeginTx(ctx, pgx.TxOptions{})
    require.NoError(t, err)
    defer tx.Rollback(ctx)  // Auto-cleanup

    // All operations in tx are isolated
    _, err = tx.Exec(ctx, "INSERT INTO users (name) VALUES ($1)", "test")
    require.NoError(t, err)

    // Query within same transaction sees the insert
    var name string
    err = tx.QueryRow(ctx, "SELECT name FROM users WHERE name = $1", "test").Scan(&name)
    require.NoError(t, err)

    // No commit = automatic rollback = clean state for next test
}
```

## Troubleshooting

**"Test database not available"**
- Set `TEST_DATABASE_URL` environment variable
- Verify database exists and is accessible

**Tests interfering with each other**
- Use transaction-based isolation (see above)
- Or use `defer testDB.Clean()` with TRUNCATE

**Golden test failures after schema change**
- Update baseline: `cp testdata/golden/TestName.json testdata/golden/TestName.json.baseline`
- Review the diff to ensure changes are intentional

## Test Data Cleanup

For custom cleanup between tests:

```go
// Run arbitrary cleanup SQL
pgxkit.CleanupTestData(
    "TRUNCATE users CASCADE",
    "DELETE FROM sessions WHERE expired = true",
)
```

## Test Pool Sizing

Test pools use smaller limits than production:

```go
// Defaults for test pools:
config.MaxConns = 5   // vs production: 4 × numCPU
config.MinConns = 1   // vs production: varies
```
