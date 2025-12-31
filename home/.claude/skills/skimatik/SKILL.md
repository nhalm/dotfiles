---
name: skimatik
description: Database-first Go code generator for PostgreSQL. Triggers when writing .sql query files with skimatik annotations (-- name:, -- param:, -- cursor_columns:), configuring skimatik.yaml, debugging skimatik parsing errors, or understanding generated repository patterns. Do NOT trigger for general SQL writing without skimatik context or PostgreSQL administration.
---

# skimatik - SQL Query Writing Guide

skimatik generates type-safe Go repository code from PostgreSQL schemas and annotated SQL query files.

## File Organization

**Query files:**
- Place `.sql` files in directory specified by `queries.directory` in skimatik.yaml
- One or more queries per file
- File name becomes the Queries struct name (e.g., `users.sql` → `UsersQueries`)

**Generated code:**
- Output to `output.directory` (default: `./repository/generated`)
- DO NOT manually edit generated `*_generated.go` files

**Dependencies:**
- Generated code requires `github.com/nhalm/pgxkit` for database connection
- `github.com/google/uuid` for UUID types
- `github.com/jackc/pgx/v5` as the PostgreSQL driver

## Query Annotations

### Name Annotation (Required)

```sql
-- name: FunctionName :return_type
```

**Return types:**
- `:one` - Returns `(*ResultType, error)` - returns `ErrNotFound` if no row
- `:many` - Returns `([]ResultType, error)` - returns empty slice if no rows
- `:exec` - Returns `error` only - for UPDATE/DELETE/INSERT without RETURNING

**Rules:**
- Function name must be valid Go identifier (PascalCase recommended)
- Name must be unique across ALL query files in the queries directory
- `:one` and `:many` require SELECT or CTE (WITH ... SELECT)
- `:exec` cannot use SELECT statements

### Parameter Annotations (Optional)

Override auto-detected parameter types. Use when you need nullable parameters or skimatik detects the wrong type.

```sql
-- param: $N parameter_name go_type
-- param: $M parameter_name go_type
```

**Format:**
- `$N` - Position (1-based, must be sequential: $1, $2, $3...)
- `parameter_name` - Snake_case name for Go parameter
- `go_type` - Go type (use `*type` for nullable)

**Example:**
```sql
-- name: ListUsersWithOptionalFilters :many
-- param: $1 limit int
-- param: $2 is_active *bool
-- param: $3 name_filter *string
SELECT id, name, email, is_active, created_at
FROM users
WHERE ($2::boolean IS NULL OR is_active = $2)
  AND ($3::text IS NULL OR name ILIKE $3)
ORDER BY created_at DESC
LIMIT $1;
```

### Result Annotations (Optional)

Override auto-detected result column types:

```sql
-- result: column_name go_type
```

**Example:**
```sql
-- name: GetUserCount :one
-- result: total int
SELECT COUNT(*) as total FROM users;
```

### Cursor Columns (For Pagination)

Enable cursor-based pagination for `:many` queries:

```sql
-- cursor_columns: col1, col2
```

**Requirements:**
- Only valid for `:many` queries
- All columns MUST be in SELECT clause
- Query must NOT include ORDER BY (sort via `orderBy` param at runtime)
- Columns should be indexed
- Forward-only (no BeforeCursor)

**Example:**
```sql
-- name: GetPublishedPosts :many
-- cursor_columns: published_at, id
SELECT id, title, content, published_at
FROM posts
WHERE is_published = true
```

**Generates TWO functions:**
```go
// Regular - all results
func (r *PostsQueries) GetPublishedPosts(ctx context.Context) ([]GetPublishedPostsResult, error)

// Paginated - orderBy separate from params
func (r *PostsQueries) GetPublishedPostsPaginated(
    ctx context.Context,
    orderBy string,          // Must be "published_at" or "id"
    params PaginationParams,
) (*PaginationResult[GetPublishedPostsResult], error)
```

## SQL Query Patterns

### Single Row (:one)

```sql
-- name: GetUserByEmail :one
SELECT id, name, email, created_at
FROM users
WHERE email = $1 AND is_active = true;
```

### Multiple Rows (:many)

```sql
-- name: GetActiveUsers :many
SELECT id, name, email, created_at
FROM users
WHERE is_active = true
ORDER BY created_at DESC
LIMIT $1;
```

### Execute (:exec)

```sql
-- name: DeactivateUser :exec
UPDATE users SET is_active = false WHERE id = $1;

-- name: DeleteOldSessions :exec
DELETE FROM sessions WHERE expires_at < NOW();
```

### JOINs

```sql
-- name: GetPostWithAuthor :one
SELECT p.id, p.title, p.content, p.author_id,
       u.name as author_name, u.email as author_email
FROM posts p
JOIN users u ON p.author_id = u.id
WHERE p.id = $1;
```

### LEFT JOIN with NULLable Results

```sql
-- name: GetPostWithOptionalAuthor :one
-- result: author_name *string
-- result: author_email *string
SELECT p.id, p.title, p.content,
       u.name as author_name, u.email as author_email
FROM posts p
LEFT JOIN users u ON p.author_id = u.id
WHERE p.id = $1;
```

### Aggregations

```sql
-- name: GetUserStats :one
SELECT
    COUNT(DISTINCT p.id) as post_count,
    COUNT(DISTINCT c.id) as comment_count
FROM users u
LEFT JOIN posts p ON u.id = p.author_id
LEFT JOIN comments c ON u.id = c.author_id
WHERE u.id = $1
GROUP BY u.id;
```

### CTEs

```sql
-- name: GetTopAuthors :many
WITH author_stats AS (
    SELECT author_id, COUNT(*) as post_count
    FROM posts
    WHERE is_published = true
    GROUP BY author_id
)
SELECT u.id, u.name, u.email, a.post_count
FROM users u
JOIN author_stats a ON u.id = a.author_id
ORDER BY a.post_count DESC
LIMIT $1;
```

### Nullable Parameter Pattern

Use `IS NULL OR` for optional filters. The cast ensures PostgreSQL knows the parameter type:

```sql
-- name: SearchPosts :many
-- param: $1 author_id *uuid.UUID
-- param: $2 is_published *bool
-- param: $3 limit int
SELECT id, title, content, author_id, is_published, created_at
FROM posts
WHERE ($1::uuid IS NULL OR author_id = $1)
  AND ($2::boolean IS NULL OR is_published = $2)
ORDER BY created_at DESC
LIMIT $3;
```

### COALESCE for Defaults

```sql
-- name: GetUserDisplayName :one
SELECT id, COALESCE(display_name, name) as display_name
FROM users
WHERE id = $1;
```

### RETURNING Clause

```sql
-- name: CreateUserReturning :one
INSERT INTO users (id, name, email)
VALUES ($1, $2, $3)
RETURNING id, name, email, created_at;
```

### Upsert (ON CONFLICT)

```sql
-- name: UpsertUserPreference :one
INSERT INTO user_preferences (user_id, key, value)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value
RETURNING user_id, key, value;
```

## Anti-Patterns (What NOT to Do)

**Don't use ORDER BY with cursor_columns:**
```sql
-- WRONG: will cause validation error
-- name: GetPosts :many
-- cursor_columns: created_at
SELECT * FROM posts ORDER BY created_at DESC;  -- Remove ORDER BY
```

**Don't use SELECT with :exec:**
```sql
-- WRONG: :exec cannot use SELECT
-- name: CountUsers :exec
SELECT COUNT(*) FROM users;  -- Use :one instead
```

**Don't skip parameter positions:**
```sql
-- WRONG: gap in positions
-- param: $1 name string
-- param: $3 email string  -- Missing $2!
```

**Don't annotate obvious parameters:**
```sql
-- UNNECESSARY: skimatik detects from schema
-- param: $1 id uuid.UUID  -- Skip if type is obvious from column
```

## Type Mapping

| PostgreSQL Type | NOT NULL | NULLABLE |
|----------------|----------|----------|
| `SMALLINT`, `INTEGER`, `BIGINT` | `int` | `*int` |
| `TEXT`, `VARCHAR` | `string` | `*string` |
| `BOOLEAN` | `bool` | `*bool` |
| `UUID` | `uuid.UUID` | `*uuid.UUID` |
| `TIMESTAMP`, `TIMESTAMPTZ` | `time.Time` | `*time.Time` |
| `DATE` | `time.Time` | `*time.Time` |
| `JSON`, `JSONB` | `json.RawMessage` | `*json.RawMessage` |
| `REAL`, `FLOAT4` | `float32` | `*float32` |
| `DOUBLE PRECISION` | `float64` | `*float64` |
| `NUMERIC`, `DECIMAL` | `float64` | `*float64` |
| `BYTEA` | `[]byte` | `*[]byte` |

**Warnings:**
- `BIGINT` → `int`: May overflow on 32-bit systems for very large values
- `NUMERIC`/`DECIMAL` → `float64`: Loses precision for financial data. Use `-- result:` annotation with custom type if needed.

**Aggregates:**
- `COUNT(*)` - Always `int` (returns 0, not NULL, on empty)
- `SUM()`, `AVG()`, `MAX()`, `MIN()` - Can be NULL if no rows

## skimatik.yaml Configuration

```yaml
database:
  dsn: "postgres://user:pass@localhost:5432/dbname?sslmode=disable"
  schema: "public"

output:
  directory: "./repository/generated"
  package: "generated"

default_functions: "all"  # or ["create", "get", "update", "delete", "list", "paginate"]

tables:
  users:
  posts:
    functions: ["create", "get", "list"]  # Override per table
  comments:

queries:
  directory: "./database/queries"

types:
  mappings:
    user_status: "UserStatus"  # Custom enum mapping

verbose: true  # Print detailed parsing logs
```

## Common Errors and Fixes

| Error | Fix |
|-------|-----|
| `query name cannot be empty` | Add `-- name: FunctionName :type` |
| `query name 'get-users' is not a valid Go identifier` | Use PascalCase: `GetUsers` |
| `query type :one requires SELECT statement` | Change to `:exec` or add RETURNING |
| `query type :exec cannot use SELECT` | Change to `:one` or `:many` |
| `duplicate parameter annotation for $1` | Remove duplicate `-- param: $1` |
| `parameter annotations must be sequential, missing $2` | Add missing `-- param: $2` |
| `cursor_columns only valid for :many` | Change query type to `:many` |
| `query has cursor_columns but contains ORDER BY` | Remove ORDER BY from SQL |

## Generated Code Usage

```go
import (
    "context"
    "github.com/nhalm/pgxkit"
    "yourproject/repository/generated"
)

// Initialize with pgxkit.DB (supports pgx.Pool, pgx.Conn, pgx.Tx)
db := pgxkit.NewDB()
db.Connect(ctx, "postgres://...")

// Table repository - CRUD operations
repo := generated.NewUsersRepository(db, nil)  // nil = default UUID v7
user, err := repo.Create(ctx, generated.CreateUsersParams{Name: "John", Email: "john@example.com"})
user, err := repo.GetByID(ctx, userID)
user, err := repo.Update(ctx, userID, generated.UpdateUsersParams{Name: "Jane"})
err := repo.Delete(ctx, userID)

// Custom queries from .sql files
queries := generated.NewUsersQueries(db)
users, err := queries.GetActiveUsers(ctx, 10)
user, err := queries.GetUserByEmail(ctx, "john@example.com")

// Paginated queries
result, err := queries.GetPublishedPostsPaginated(ctx, "published_at", generated.PaginationParams{Limit: 20})
if result.HasMore {
    next, err := queries.GetPublishedPostsPaginated(ctx, "published_at", generated.PaginationParams{
        Limit: 20,
        NextCursor: result.NextCursor,
    })
}

// Error handling
if generated.IsNotFound(err) { /* handle not found */ }
if generated.IsAlreadyExists(err) { /* handle duplicate */ }

// Works with transactions
tx, _ := db.Begin(ctx)
defer tx.Rollback(ctx)
repo := generated.NewUsersRepository(tx, nil)  // Same interface
user, err := repo.Create(ctx, params)
tx.Commit(ctx)
```

## Database Requirements

- PostgreSQL (any version pgx supports)
- UUID primary keys required for table-based CRUD pagination
- Custom queries with `cursor_columns` can use any indexed columns
