# SQL Query Patterns

Common patterns for skimatik SQL query files.

## Basic Queries

### Single Row (:one)

```sql
-- name: GetUserByID :one
SELECT id, name, email, created_at
FROM users
WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, name, email, created_at
FROM users
WHERE email = $1 AND is_active = true;
```

### Multiple Rows (:many)

```sql
-- name: ListActiveUsers :many
SELECT id, name, email, created_at
FROM users
WHERE is_active = true
ORDER BY created_at DESC;

-- name: ListUsersWithLimit :many
SELECT id, name, email, created_at
FROM users
WHERE is_active = true
ORDER BY created_at DESC
LIMIT $1;
```

### Execute Without Return (:exec)

```sql
-- name: DeactivateUser :exec
UPDATE users SET is_active = false WHERE id = $1;

-- name: DeleteOldSessions :exec
DELETE FROM sessions WHERE expires_at < NOW();

-- name: IncrementViewCount :exec
UPDATE posts SET view_count = view_count + 1 WHERE id = $1;
```

## JOINs

### INNER JOIN

```sql
-- name: GetPostWithAuthor :one
SELECT p.id, p.title, p.content, p.created_at,
       u.name as author_name, u.email as author_email
FROM posts p
JOIN users u ON p.author_id = u.id
WHERE p.id = $1;
```

### LEFT JOIN (with nullable results)

When using LEFT JOIN, the joined columns may be NULL even if the source column is NOT NULL:

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

### Multiple JOINs

```sql
-- name: GetCommentWithContext :one
SELECT c.id, c.content, c.created_at,
       p.title as post_title,
       u.name as author_name
FROM comments c
JOIN posts p ON c.post_id = p.id
JOIN users u ON c.author_id = u.id
WHERE c.id = $1;
```

## Aggregations

### COUNT

```sql
-- name: CountActiveUsers :one
SELECT COUNT(*) as total FROM users WHERE is_active = true;

-- name: CountPostsByAuthor :one
SELECT COUNT(*) as post_count
FROM posts
WHERE author_id = $1 AND is_published = true;
```

### Multiple Aggregates

```sql
-- name: GetUserStats :one
SELECT
    COUNT(DISTINCT p.id) as post_count,
    COUNT(DISTINCT c.id) as comment_count,
    COALESCE(SUM(p.view_count), 0) as total_views
FROM users u
LEFT JOIN posts p ON u.id = p.author_id
LEFT JOIN comments c ON u.id = c.author_id
WHERE u.id = $1
GROUP BY u.id;
```

### Aggregates with NULL handling

SUM, AVG, MAX, MIN return NULL on empty sets:

```sql
-- name: GetPostStats :one
-- result: avg_views *float64
-- result: max_views *int
SELECT
    COUNT(*) as post_count,
    AVG(view_count) as avg_views,
    MAX(view_count) as max_views
FROM posts
WHERE author_id = $1;
```

## CTEs (Common Table Expressions)

### Simple CTE

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

### CTE with DELETE/UPDATE

```sql
-- name: DeleteOldUsersBatch :one
-- param: $1 batch_size int
WITH deleted AS (
    DELETE FROM users
    WHERE id IN (
        SELECT id FROM users WHERE is_active = false LIMIT $1
    )
    RETURNING id
)
SELECT COUNT(*) as deleted_count FROM deleted;
```

Note: Parameters inside CTE subqueries are detected automatically, but explicit `-- param:` annotations are recommended for clarity.

## Nullable Parameter Patterns

### Optional Filter Pattern

Use `IS NULL OR` for parameters that may be omitted:

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

### Date Range with Optional Bounds

```sql
-- name: GetPostsByDateRange :many
-- param: $1 start_date *time.Time
-- param: $2 end_date *time.Time
-- param: $3 limit int
SELECT id, title, created_at
FROM posts
WHERE ($1::timestamptz IS NULL OR created_at >= $1)
  AND ($2::timestamptz IS NULL OR created_at <= $2)
ORDER BY created_at DESC
LIMIT $3;
```

### Multiple Optional Filters

```sql
-- name: AdvancedUserSearch :many
-- param: $1 name_filter *string
-- param: $2 email_domain *string
-- param: $3 is_active *bool
-- param: $4 created_after *time.Time
-- param: $5 limit int
SELECT id, name, email, is_active, created_at
FROM users
WHERE ($1::text IS NULL OR name ILIKE '%' || $1 || '%')
  AND ($2::text IS NULL OR email LIKE '%@' || $2)
  AND ($3::boolean IS NULL OR is_active = $3)
  AND ($4::timestamptz IS NULL OR created_at >= $4)
ORDER BY created_at DESC
LIMIT $5;
```

## INSERT Patterns

### INSERT with RETURNING

```sql
-- name: CreateUser :one
INSERT INTO users (id, name, email)
VALUES ($1, $2, $3)
RETURNING id, name, email, created_at, updated_at;
```

### Upsert (ON CONFLICT)

```sql
-- name: UpsertUserPreference :one
INSERT INTO user_preferences (user_id, key, value)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value
RETURNING user_id, key, value, updated_at;

-- name: UpsertUserPreferenceIgnore :exec
INSERT INTO user_preferences (user_id, key, value)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, key) DO NOTHING;
```

## UPDATE Patterns

### UPDATE with RETURNING

```sql
-- name: UpdateUserEmail :one
UPDATE users
SET email = $2, updated_at = NOW()
WHERE id = $1
RETURNING id, name, email, updated_at;
```

### Conditional UPDATE

```sql
-- name: UpdateUserIfActive :one
UPDATE users
SET name = $2, updated_at = NOW()
WHERE id = $1 AND is_active = true
RETURNING id, name, email, updated_at;
```

## Utility Patterns

### COALESCE for Defaults

```sql
-- name: GetUserDisplayName :one
SELECT id, COALESCE(display_name, name) as display_name
FROM users
WHERE id = $1;
```

### CASE Expressions

```sql
-- name: GetUsersWithStatus :many
SELECT id, name, email,
    CASE
        WHEN is_active AND email_verified THEN 'active'
        WHEN is_active THEN 'pending'
        ELSE 'inactive'
    END as status
FROM users
ORDER BY created_at DESC;
```

### EXISTS Subquery

```sql
-- name: GetUsersWithPosts :many
SELECT id, name, email
FROM users u
WHERE EXISTS (
    SELECT 1 FROM posts p
    WHERE p.author_id = u.id AND p.is_published = true
);
```

### IN Clause with Arrays

Use `ANY()` with array parameters for IN-style queries:

```sql
-- name: GetUsersByIDs :many
-- param: $1 ids []uuid.UUID
SELECT id, name, email
FROM users
WHERE id = ANY($1::uuid[]);
```

Usage in Go:
```go
ids := []uuid.UUID{id1, id2, id3}
users, err := queries.GetUsersByIDs(ctx, ids)
```

Other array types:
```sql
-- Integer array
WHERE status_code = ANY($1::int[])

-- String array
WHERE tag = ANY($1::text[])
```

**Edge cases:**
- Empty array `[]uuid.UUID{}` → matches NO rows (valid, returns empty result)
- Nil slice in Go → sent as NULL, `ANY(NULL)` matches NO rows

To handle "return all if no filter":
```sql
-- name: GetUsersByIDsOrAll :many
-- param: $1 ids []uuid.UUID
SELECT id, name, email
FROM users
WHERE $1::uuid[] IS NULL OR id = ANY($1);
```

## Window Functions

skimatik supports window functions (ROW_NUMBER, RANK, DENSE_RANK, etc.):

### Ranking

```sql
-- name: GetRankedUsers :many
SELECT
    id,
    name,
    score,
    ROW_NUMBER() OVER (ORDER BY score DESC) as rank
FROM users
WHERE is_active = true
ORDER BY score DESC;
```

### Partitioned Ranking

```sql
-- name: GetTopPostsByCategory :many
-- result: rank int
SELECT
    p.id,
    p.title,
    p.category_id,
    p.view_count,
    ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.view_count DESC) as rank
FROM posts p
WHERE p.is_published = true;
```

### Running Totals

```sql
-- name: GetOrdersWithRunningTotal :many
-- result: running_total *float64
SELECT
    id,
    order_date,
    amount,
    SUM(amount) OVER (ORDER BY order_date) as running_total
FROM orders
WHERE customer_id = $1
ORDER BY order_date;
```

## Pagination Pattern

For paginated queries, use the `:paginated` query type with ORDER BY:

```sql
-- name: GetRecentPosts :paginated
SELECT id, title, content, created_at
FROM posts
WHERE is_published = true
ORDER BY created_at DESC
```

This generates two functions:
- `GetRecentPosts()` - returns all results
- `GetRecentPostsPaginated(params)` - bidirectional cursor pagination

The ORDER BY direction (ASC/DESC) is extracted at generation time and used for cursor comparisons.
