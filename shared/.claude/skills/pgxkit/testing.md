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

    if err := testDB.Setup(); err != nil {
        t.Fatalf("Setup failed: %v", err)
    }
    defer testDB.Clean() // Verifies connection still active

    // Your test code
}
```

## Plan-Regression Testing (`EnableAssertPlan` / `AssertPlan`)

Captures the **structural query plan** (`EXPLAIN (FORMAT JSON, COSTS OFF)`) for every eligible query and compares against a baseline. Detects plan changes — a seq-scan replacing an index-scan, a nested-loop turning into a hash-join, a different join order, a new sort node — without churning on volatile fields like `Actual Total Time` or planner cost estimates.

**Use when:**
- Query performance is critical and you want CI to flag plan regressions.
- Schema changes might silently break optimization (missing index, dropped constraint).
- You want to assert structure of the plan, not result rows.

```go
func TestQueryPlan(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.RequireDB(t)
    defer testDB.Shutdown(ctx)

    db := testDB.EnableAssertPlan("TestQueryPlan")

    rows, err := db.Query(ctx, "SELECT * FROM users WHERE active = $1", true)
    require.NoError(t, err)
    rows.Close()

    db.AssertPlan(t, "TestQueryPlan")
}
```

**File workflow:**
1. First run: writes `testdata/plans/TestQueryPlan.json` and passes (logs baseline creation).
2. Subsequent runs: compares the freshly-captured plans against the file on disk, fails with a unified diff on mismatch.
3. To refresh after intentional changes: `go test -overwrite-plan` (only rewrites baselines for tests that actually run — safe with `-run`). Or `rm testdata/plans/TestQueryPlan.json` and let the next run write a fresh one.

**Coverage:**
- `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `WITH` are all captured.
- `EXPLAIN (FORMAT JSON, COSTS OFF)` plans the statement without running `ANALYZE`, so DML doesn't execute and doesn't need transaction wrapping.
- `EXPLAIN`-prefixed statements are skipped to avoid recursion.

## Golden Transcript Testing (`EnableGolden` / `AssertGolden`)

Captures the **ordered sequence of database events** a scenario produces — `BEGIN`, every `Query`/`Exec` (with SQL, normalized args, plus `rows_affected` for Exec), and the closing `COMMIT` or `ROLLBACK` — and asserts subsequent runs match the recorded baseline.

**Use when:**
- You want to detect behavior regressions: an extra UPDATE, a missing INSERT, a different argument, a `COMMIT` that became a `ROLLBACK`, a reordering of statements.
- The scenario is a multi-statement repository call where result-row comparison alone misses things.
- You want a single artifact that captures *what the code did*, not just *what it returned*.

**Result rows are NOT captured.** Golden tests assert on the event stream and arguments, not on returned data. For "did this row change" assertions, scan in the test body and assert there, or use `AssertPlan` for plan-shape stability.

```go
func TestCreateOrder(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.RequireDB(t)
    defer testDB.Shutdown(ctx)

    golden := testDB.EnableGolden("TestCreateOrder")

    // Run the code under test using golden as the DB
    tx, err := golden.BeginTx(ctx, pgx.TxOptions{})
    require.NoError(t, err)
    defer tx.Rollback(ctx)

    var orderID int
    err = tx.QueryRow(ctx,
        "INSERT INTO orders (total) VALUES ($1) RETURNING id", 100,
    ).Scan(&orderID)
    require.NoError(t, err)

    require.NoError(t, tx.Commit(ctx))

    golden.AssertGolden(t, "TestCreateOrder")
}
```

**File workflow:**
1. First run: writes `testdata/golden/TestCreateOrder.json`, passes (logs baseline creation).
2. Subsequent runs: compares against the baseline, fails with a unified diff on mismatch.
3. To regenerate after intentional changes: `go test -overwrite-golden` (only rewrites goldens for tests that actually run — safe with `-run`).

**Default normalization** (so transcripts compare cleanly across runs):
- `time.Time` (and `*time.Time`) → `<TIMESTAMP>`
- UUIDs (`uuid.UUID`, `[16]byte`, canonical UUID strings) → `<UUID:N>` (first-seen, scenario-scoped, same value gets the same placeholder)

Args have no column hint, so other types pass through unchanged.

**Custom normalizers** run before the defaults — register via `WithGoldenNormalizer`:
```go
golden := testDB.EnableGolden("TestCreateOrder",
    pgxkit.WithGoldenNormalizer(func(v any) (any, bool) {
        if order, ok := v.(OrderNumber); ok {
            return "<ORDER>", true
        }
        return nil, false
    }),
)
```

**Limitations:**
- Sequential scenarios only. Concurrent fan-out within one scenario produces a non-deterministic transcript (the underlying hook accumulator is mutex-protected, but ordering is not).
- Result rows are not captured — see above.
- Don't `defer` any cleanup of the baseline file — the baseline is meant to persist; that's the whole point.

## Plan-Regression vs Golden — Which?

| Question | Answer |
|----------|--------|
| Did the query *plan* change? | `AssertPlan` |
| Did the *behavior* change (extra/missing statement, different args, COMMIT→ROLLBACK)? | `AssertGolden` |
| Both? | Pick one per scenario. `EnableGolden` and `EnableAssertPlan` each return a fresh `*DB`, so they don't compose on one instance. |

## Parallel Test Safety

Tests using `RequireDB` are safe for parallel execution — each gets its own context.

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
            t.Parallel()
            ctx := context.Background()
            testDB := pgxkit.RequireDB(t)
            defer testDB.Shutdown(ctx)
            // Test code
        })
    }
}
```

Plan-regression and Golden tests should NOT run in parallel within a single scenario — both rely on a shared step counter / hook ordering that assumes sequential calls.

## Test Data Isolation

Use transactions for test isolation when you can't truncate between tests:

```go
func TestWithTransaction(t *testing.T) {
    ctx := context.Background()
    testDB := pgxkit.RequireDB(t)
    defer testDB.Shutdown(ctx)

    tx, err := testDB.BeginTx(ctx, pgx.TxOptions{})
    require.NoError(t, err)
    defer tx.Rollback(ctx)  // Auto-cleanup

    _, err = tx.Exec(ctx, "INSERT INTO users (name) VALUES ($1)", "test")
    require.NoError(t, err)

    var name string
    err = tx.QueryRow(ctx, "SELECT name FROM users WHERE name = $1", "test").Scan(&name)
    require.NoError(t, err)

    // No commit = automatic rollback = clean state for next test
}
```

## Troubleshooting

**"Test database not available"**
- Set `TEST_DATABASE_URL` environment variable.
- Verify database exists and is accessible.

**Tests interfering with each other**
- Use transaction-based isolation (above).
- Or use `CleanupTestData()` with `TRUNCATE` statements.

**Plan-regression test fails after schema change**
- `go test -overwrite-plan -run TestName` regenerates the plan baseline for just that test. Inspect the diff with `git diff testdata/plans/TestName.json` before committing.

**Golden test fails after intentional behavior change**
- `go test -overwrite-golden -run TestName` regenerates the baseline for just that test. Inspect the diff with `git diff testdata/golden/TestName.json` before committing.

**Golden test passes every run but never catches anything**
- You're probably deferring something that deletes the baseline (don't). The baseline file at `testdata/golden/<name>.json` should be committed and persistent.

## Test Data Cleanup

For custom cleanup between tests:

```go
pgxkit.CleanupTestData(
    "TRUNCATE users CASCADE",
    "DELETE FROM sessions WHERE expired = true",
)
```

## Test Pool Sizing

TestDB uses the same pool defaults as production. For tests, consider smaller pools:

```go
testDB := pgxkit.NewTestDB()
err := testDB.Connect(ctx, os.Getenv("TEST_DATABASE_URL"),
    pgxkit.WithMaxConns(5),
    pgxkit.WithMinConns(1),
)
```
