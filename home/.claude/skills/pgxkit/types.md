# pgxkit Type Conversions

Convert between Go types and pgtype for NULL handling.

**See also:** core.md (query patterns), retry.md (error types for validation failures)

```go
import (
    "github.com/nhalm/pgxkit"
    "github.com/jackc/pgx/v5/pgtype"
    "github.com/google/uuid"
)
```

## Pattern

- `ToPgx*(input) → pgtype.T` - Go to PostgreSQL
- `FromPgx*(pgtype.T) → output` - PostgreSQL to Go

## Quick Decision

```
Column allows NULL?
  → Use pointer variants: ToPgxText(*string), FromPgxText() → *string

Column is NOT NULL?
  → Use value variants: ToPgxTextFromString(string), FromPgxTextToString() → string
```

## Nullable (Pointer) Variants

For columns that allow NULL. Input/output are pointers.

```go
// String/Text
ToPgxText(*string) → pgtype.Text
FromPgxText(pgtype.Text) → *string

// Integers
ToPgxInt8(*int64) → pgtype.Int8
FromPgxInt8(pgtype.Int8) → *int64
ToPgxInt4(*int32) → pgtype.Int4
FromPgxInt4(pgtype.Int4) → *int32
ToPgxInt2(*int16) → pgtype.Int2
FromPgxInt2(pgtype.Int2) → *int16

// Boolean
ToPgxBool(*bool) → pgtype.Bool
FromPgxBool(pgtype.Bool) → *bool

// Floats
ToPgxFloat8(*float64) → pgtype.Float8
FromPgxFloat8(pgtype.Float8) → *float64
ToPgxFloat4(*float32) → pgtype.Float4
FromPgxFloat4(pgtype.Float4) → *float32
ToPgxNumeric(*float64) → pgtype.Numeric  // 6 decimal places
FromPgxNumeric(pgtype.Numeric) → *float64

// Time
ToPgxTimestamp(*time.Time) → pgtype.Timestamp
FromPgxTimestamp(pgtype.Timestamp) → *time.Time
ToPgxTimestamptz(*time.Time) → pgtype.Timestamptz
FromPgxTimestamptz(pgtype.Timestamptz) → time.Time
FromPgxTimestamptzPtr(pgtype.Timestamptz) → *time.Time
ToPgxDate(*time.Time) → pgtype.Date
FromPgxDate(pgtype.Date) → *time.Time
ToPgxTime(*time.Time) → pgtype.Time
FromPgxTime(pgtype.Time) → *time.Time

// UUID
ToPgxUUID(uuid.UUID) → pgtype.UUID
FromPgxUUID(pgtype.UUID) → uuid.UUID
ToPgxUUIDFromPtr(*uuid.UUID) → pgtype.UUID
FromPgxUUIDToPtr(pgtype.UUID) → *uuid.UUID
```

## Non-Null (Value) Variants

For NOT NULL columns. Input/output are values.

```go
ToPgxTextFromString(string) → pgtype.Text
FromPgxTextToString(pgtype.Text) → string

ToPgxBoolFromBool(bool) → pgtype.Bool
FromPgxBoolToBool(pgtype.Bool) → bool

ToPgxInt4FromInt(*int) → pgtype.Int4  // Note: still takes pointer
FromPgxInt4ToInt(pgtype.Int4) → *int
```

## Arrays

```go
ToPgxTextArray([]string) → pgtype.Array[pgtype.Text]
FromPgxTextArray(pgtype.Array[pgtype.Text]) → []string

ToPgxInt8Array([]int64) → pgtype.Array[pgtype.Int8]
FromPgxInt8Array(pgtype.Array[pgtype.Int8]) → []int64
```

## Usage Examples

### Insert with Type Conversion

```go
name := "Alice"
createdAt := time.Now()
var bio *string = nil  // Optional field

_, err := db.Exec(ctx, `
    INSERT INTO users (name, created_at, bio) VALUES ($1, $2, $3)`,
    pgxkit.ToPgxTextFromString(name),      // NOT NULL
    pgxkit.ToPgxTimestamptz(&createdAt),   // NOT NULL
    pgxkit.ToPgxText(bio),                 // NULL allowed
)
```

### Scan with Type Conversion

```go
var nameCol pgtype.Text
var createdCol pgtype.Timestamptz
var bioCol pgtype.Text

err := db.QueryRow(ctx,
    "SELECT name, created_at, bio FROM users WHERE id = $1", id,
).Scan(&nameCol, &createdCol, &bioCol)
if err != nil {
    return nil, err
}

user := &User{
    Name:      pgxkit.FromPgxTextToString(nameCol),
    CreatedAt: pgxkit.FromPgxTimestamptz(createdCol),
    Bio:       pgxkit.FromPgxText(bioCol),  // Returns *string (may be nil)
}
```

### Working with Arrays

```go
// Insert array
tags := []string{"golang", "postgres", "api"}
_, err := db.Exec(ctx,
    "INSERT INTO posts (title, tags) VALUES ($1, $2)",
    pgxkit.ToPgxTextFromString("My Post"),
    pgxkit.ToPgxTextArray(tags),
)

// Query with array parameter (ANY pattern)
userIDs := []int64{1, 2, 3}
rows, err := db.Query(ctx,
    "SELECT name FROM users WHERE id = ANY($1)",
    pgxkit.ToPgxInt8Array(userIDs),
)

// Scan array result
var tagsCol pgtype.Array[pgtype.Text]
err := row.Scan(&tagsCol)
tags := pgxkit.FromPgxTextArray(tagsCol)  // []string
```

### Handling Optional API Fields

```go
type CreateUserRequest struct {
    Name     string  `json:"name"`
    Email    string  `json:"email"`
    Nickname *string `json:"nickname,omitempty"`  // Optional
}

func CreateUser(ctx context.Context, db *pgxkit.DB, req CreateUserRequest) error {
    _, err := db.Exec(ctx, `
        INSERT INTO users (name, email, nickname) VALUES ($1, $2, $3)`,
        pgxkit.ToPgxTextFromString(req.Name),
        pgxkit.ToPgxTextFromString(req.Email),
        pgxkit.ToPgxText(req.Nickname),  // Handles nil → NULL
    )
    return err
}
```
