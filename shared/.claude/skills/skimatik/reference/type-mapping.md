# Type Mapping Reference

PostgreSQL to Go type mappings used by skimatik.

## Standard Type Mappings

| PostgreSQL Type | NOT NULL Go Type | NULLABLE Go Type |
|-----------------|------------------|------------------|
| `SMALLINT`, `INT2` | `int` | `*int` |
| `INTEGER`, `INT`, `INT4` | `int` | `*int` |
| `BIGINT`, `INT8` | `int` | `*int` |
| `SERIAL` | `int` | `*int` |
| `SMALLSERIAL` | `int` | `*int` |
| `BIGSERIAL` | `int` | `*int` |
| `TEXT` | `string` | `*string` |
| `VARCHAR`, `CHARACTER VARYING` | `string` | `*string` |
| `CHAR`, `CHARACTER` | `string` | `*string` |
| `BOOLEAN`, `BOOL` | `bool` | `*bool` |
| `UUID` | `uuid.UUID` | `*uuid.UUID` |
| `TIMESTAMP` | `time.Time` | `*time.Time` |
| `TIMESTAMPTZ`, `TIMESTAMP WITH TIME ZONE` | `time.Time` | `*time.Time` |
| `DATE` | `time.Time` | `*time.Time` |
| `TIME` | `time.Time` | `*time.Time` |
| `JSON` | `json.RawMessage` | `*json.RawMessage` |
| `JSONB` | `json.RawMessage` | `*json.RawMessage` |
| `BYTEA` | `[]byte` | `*[]byte` |
| `REAL`, `FLOAT4` | `float32` | `*float32` |
| `DOUBLE PRECISION`, `FLOAT8` | `float64` | `*float64` |
| `NUMERIC`, `DECIMAL` | `float64` | `*float64` |

## Design Philosophy

skimatik uses idiomatic Go types:

- **All integers → `int`**: Whether SMALLINT, INTEGER, BIGINT, or SERIAL variants, maps to Go's native `int`
- **NOT NULL → value types**: Direct types like `int`, `string`, `bool`
- **NULLABLE → pointer types**: NULL support via `*int`, `*string`, `*bool`
- **No pgtype dependency**: Pure Go types only

## Custom Query Annotations

In `.sql` query files, you can override type mappings using `-- param:` and `-- result:` annotations.

### Supported Types in Annotations

**Primitive types:**
- `int`, `*int`
- `string`, `*string`
- `bool`, `*bool`
- `float32`, `*float32`
- `float64`, `*float64`

**Standard library types:**
- `time.Time`, `*time.Time`
- `json.RawMessage`, `*json.RawMessage`
- `[]byte`, `*[]byte`

**Third-party types:**
- `uuid.UUID`, `*uuid.UUID` (requires `github.com/google/uuid`)

**Array types:**
- `[]int`, `[]string`, `[]uuid.UUID`, `[]bool`

### Example: Override Default Mappings

```sql
-- name: GetUserData :one
-- param: user_id uuid.UUID
-- result: avatar_data []byte
-- result: settings json.RawMessage
SELECT avatar_data, settings
FROM users
WHERE id = $1;
```

## Warnings and Caveats

### Integer Overflow Risk

All PostgreSQL integers map to Go `int`:
- On 64-bit systems: `int` is 64-bit, safe for BIGINT
- On 32-bit systems: `int` is 32-bit, BIGINT values may overflow

If you need guaranteed 64-bit integers, use a custom type mapping.

### NUMERIC/DECIMAL Precision Loss

`NUMERIC` and `DECIMAL` map to `float64`, which can lose precision for:
- Financial calculations requiring exact decimal arithmetic
- Very large numbers (>15 significant digits)

**Solution**: Use `-- result:` annotation with a custom decimal type:

```sql
-- name: GetAccountBalance :one
-- result: balance string
SELECT balance FROM accounts WHERE id = $1;
```

Then parse in application code:
```go
import "github.com/shopspring/decimal"

result, err := queries.GetAccountBalance(ctx, accountID)
balance, err := decimal.NewFromString(result.Balance)
```

## Aggregate Function Types

| Function | Return Type | Notes |
|----------|-------------|-------|
| `COUNT(*)` | `int` | Never NULL, returns 0 on empty |
| `COUNT(column)` | `int` | Never NULL, returns 0 on empty |
| `SUM(int)` | `*int` | NULL if no rows |
| `SUM(float)` | `*float64` | NULL if no rows |
| `AVG(*)` | `*float64` | NULL if no rows |
| `MAX(*)` | Matches column type, nullable | NULL if no rows |
| `MIN(*)` | Matches column type, nullable | NULL if no rows |

### Example: Handling Aggregate NULLs

```sql
-- name: GetUserStats :one
-- result: total_posts int
-- result: avg_views *float64
-- result: max_views *int
SELECT
    COUNT(*) as total_posts,      -- Never NULL
    AVG(view_count) as avg_views, -- Can be NULL
    MAX(view_count) as max_views  -- Can be NULL
FROM posts
WHERE author_id = $1;
```

## Array Types

PostgreSQL arrays map to Go slices:

| PostgreSQL | Go |
|------------|-----|
| `INTEGER[]` | `[]int` |
| `TEXT[]` | `[]string` |
| `UUID[]` | `[]uuid.UUID` |
| `BOOLEAN[]` | `[]bool` |

## Custom Type Mappings

Configure in `skimatik.yaml`:

```yaml
types:
  mappings:
    user_status: "UserStatus"
    payment_state: "PaymentState"
```

For PostgreSQL ENUMs:

```sql
-- PostgreSQL
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'pending');

CREATE TABLE users (
    id UUID PRIMARY KEY,
    status user_status NOT NULL
);
```

```go
// Go - you must define this type
type UserStatus string

const (
    UserStatusActive   UserStatus = "active"
    UserStatusInactive UserStatus = "inactive"
    UserStatusPending  UserStatus = "pending"
)
```

## Required Imports

skimatik generates these imports as needed:

```go
import (
    "encoding/json"           // for json.RawMessage
    "time"                    // for time.Time
    "github.com/google/uuid"  // for uuid.UUID
)
```

## Working with Nullable Fields

Nullable columns use pointers. Handle them appropriately:

```go
user, err := repo.Get(ctx, id)

// Check nullable field
if user.Bio != nil {
    fmt.Printf("Bio: %s\n", *user.Bio)
}

// Set nullable field
newBio := "Software engineer"
updateParams := UpdateUsersParams{
    Bio: &newBio,
}

// Set to NULL
updateParams := UpdateUsersParams{
    Bio: nil,
}
```
