# Query Annotations

Complete reference for skimatik SQL file annotations.

## Name Annotation (Required)

Every query must have a name annotation as the first comment:

```sql
-- name: FunctionName :return_type
```

### Return Types

| Type | Go Return | Behavior |
|------|-----------|----------|
| `:one` | `(*ResultType, error)` | Single row. Returns `ErrNotFound` if no row. |
| `:many` | `([]ResultType, error)` | Multiple rows. Returns empty slice if none. |
| `:paginated` | See below | Bidirectional pagination. Generates TWO functions. |
| `:exec` | `error` | No data returned. For UPDATE/DELETE/INSERT. |

### Rules

- **Function name**: Must be valid Go identifier (PascalCase recommended)
- **Uniqueness**: Name must be unique across ALL query files in the queries directory
- **SQL type matching**:
  - `:one`, `:many`, and `:paginated` require SELECT or CTE (WITH ... SELECT)
  - `:paginated` requires ORDER BY clause (direction is extracted at generation time)
  - `:exec` cannot use SELECT statements
  - Use `:one` with RETURNING clause for INSERT/UPDATE that returns data

### Examples

```sql
-- name: GetUserByID :one
SELECT id, name, email FROM users WHERE id = $1;

-- name: ListActiveUsers :many
SELECT id, name FROM users WHERE is_active = true;

-- name: DeactivateUser :exec
UPDATE users SET is_active = false WHERE id = $1;

-- name: CreateUser :one
INSERT INTO users (id, name, email) VALUES ($1, $2, $3)
RETURNING id, name, email, created_at;
```

## Parameter Annotations (Optional)

Override auto-detected parameter types:

```sql
-- param: $N parameter_name go_type
```

### Format

- `$N` - Parameter position (1-based)
- `parameter_name` - Snake_case name for the Go parameter
- `go_type` - Go type (prefix with `*` for nullable)

### Rules

- Positions must be sequential starting at `$1`
- No gaps allowed (`$1`, `$2`, `$3` - not `$1`, `$3`)
- Partial annotations allowed: annotate only parameters that need type overrides

### When to Use

1. **Nullable parameters** - skimatik defaults to non-nullable
2. **Type override** - when auto-detection is wrong
3. **Custom names** - when auto-generated names are unclear

### Supported Go Types

```
int, *int                          - All integer types
string, *string                    - TEXT, VARCHAR
bool, *bool                        - BOOLEAN
uuid.UUID, *uuid.UUID              - UUID
time.Time, *time.Time              - TIMESTAMP, DATE
float32, *float32                  - REAL
float64, *float64                  - DOUBLE PRECISION, NUMERIC
json.RawMessage, *json.RawMessage  - JSON, JSONB
[]byte, *[]byte                    - BYTEA
```

### Example

```sql
-- name: SearchUsers :many
-- param: $1 name_filter *string
-- param: $2 is_active *bool
-- param: $3 limit int
SELECT id, name, email FROM users
WHERE ($1::text IS NULL OR name ILIKE $1)
  AND ($2::boolean IS NULL OR is_active = $2)
LIMIT $3;
```

Generated function signature:
```go
func (r *UsersQueries) SearchUsers(ctx context.Context, nameFilter *string, isActive *bool, limit int) ([]SearchUsersResult, error)
```

## Result Annotations (Optional)

Override auto-detected result column types:

```sql
-- result: column_name go_type
```

### When to Use

1. **LEFT JOIN columns** - may be NULL even if source column is NOT NULL
2. **Aggregate functions** - SUM, AVG, MAX, MIN can return NULL
3. **Computed columns** - when type detection fails
4. **Custom types** - for enums or domain types

### Example

```sql
-- name: GetPostWithOptionalAuthor :one
-- result: author_name *string
-- result: author_email *string
SELECT p.id, p.title,
       u.name as author_name, u.email as author_email
FROM posts p
LEFT JOIN users u ON p.author_id = u.id
WHERE p.id = $1;
```

## Paginated Query Type (:paginated)

For bidirectional cursor-based pagination with fixed ORDER BY direction:

```sql
-- name: GetRecentPosts :paginated
SELECT id, title, content, created_at
FROM posts
WHERE is_published = true
ORDER BY created_at DESC
```

### Requirements

- ORDER BY clause is **required**
- ORDER BY column must be in the SELECT list
- Only simple column references supported (no expressions like `ORDER BY LOWER(name)`)
- Sort direction (ASC/DESC) is extracted at generation time

### How It Works

- Direction is fixed by your SQL (no runtime `orderBy` parameter)
- skimatik automatically infers direction from the ORDER BY clause
- DESC ordering: uses `<` for forward pagination, `>` for backward
- ASC ordering: uses `>` for forward pagination, `<` for backward
- Supports bidirectional navigation via `NextCursor` and `BeforeCursor`

**Generates TWO functions:**
1. Regular function - returns all results using your ORDER BY
2. Paginated function - cursor-based pagination with same direction

### Example

```sql
-- name: GetRecentPosts :paginated
SELECT id, title, created_at
FROM posts
WHERE is_published = true
ORDER BY created_at DESC
```

Generated functions:
```go
// All results (with ORDER BY applied)
func (r *PostsQueries) GetRecentPosts(ctx context.Context, db pgxkit.DBConn) ([]GetRecentPostsResult, error)

// Paginated - no orderBy param needed, uses DESC from SQL
func (r *PostsQueries) GetRecentPostsPaginated(
    ctx context.Context,
    db pgxkit.DBConn,
    params PaginationParams,
) (*PaginationResult[GetRecentPostsResult], error)
```

Usage:
```go
// First page
result, err := queries.GetRecentPostsPaginated(ctx, db, PaginationParams{Limit: 20})

// Next page (forward)
if result.HasMore {
    next, err := queries.GetRecentPostsPaginated(ctx, db, PaginationParams{
        Limit:      20,
        NextCursor: result.NextCursor,
    })
}

// Previous page (backward)
if result.HasPrevious {
    prev, err := queries.GetRecentPostsPaginated(ctx, db, PaginationParams{
        Limit:        20,
        BeforeCursor: result.BeforeCursor,
    })
}
```

### With Parameters

```sql
-- name: GetPostsByAuthor :paginated
-- param: $1 author_id uuid.UUID
SELECT id, title, created_at
FROM posts
WHERE author_id = $1
ORDER BY created_at DESC
```

Generated:
```go
// Filter params come BEFORE PaginationParams
func (r *PostsQueries) GetPostsByAuthorPaginated(
    ctx context.Context,
    db pgxkit.DBConn,
    authorId uuid.UUID,
    params PaginationParams,
) (*PaginationResult[GetPostsByAuthorResult], error)
```

## CTE Parameter Extraction

skimatik automatically extracts parameters from CTEs (Common Table Expressions) containing DELETE, UPDATE, or INSERT statements:

```sql
-- name: ArchiveOldPosts :one
-- param: $1 days_old int
WITH archived AS (
    DELETE FROM posts
    WHERE created_at < NOW() - INTERVAL '$1 days'
    RETURNING id
)
SELECT COUNT(*) as archived_count FROM archived;
```

Parameters are detected in CTEs just as they are in the main query body. This enables complex data modification queries with RETURNING clauses.

## Annotation Format

All annotations appear as SQL comments before the query. The `-- name:` annotation is required first, other annotations can appear in any order:

```sql
-- name: FunctionName :type
-- param: $1 name type
-- param: $2 name type
-- result: column type
SELECT ...
```
