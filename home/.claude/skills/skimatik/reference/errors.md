# Errors Reference

Common errors from skimatik generation and their fixes.

## Generation-Time Errors

### Configuration Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `database connection string (DSN) is required` | Missing DSN | Add `database.dsn` to config |
| `must enable either table generation or query generation` | No tables or queries specified | Add `tables:` or `queries:` section |
| `queries directory does not exist` | Invalid queries path | Check path in `queries.directory` |
| `failed to create output directory: permission denied` | Can't write to output | Check directory permissions |

### Table Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `table has no primary key` | Table missing PK | Add primary key to table |
| `composite primary keys are not supported` | Multi-column PK | Use single-column PK |
| `primary key column X not found` | PK column missing | Check column exists in table |

### Query Annotation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `query name cannot be empty` | Missing `-- name:` | Add `-- name: FuncName :type` |
| `query SQL cannot be empty` | No SQL after annotation | Add SQL statement |
| `query name 'X' is not a valid Go identifier` | Invalid name | Use PascalCase, no special chars |
| `query type :one requires SELECT statement` | SELECT with `:exec` | Change to `:one` or `:many` |
| `query type :exec cannot use SELECT` | `:exec` with SELECT | Use `:one`/`:many` or remove RETURNING |

### Parameter Annotation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `duplicate parameter annotation for $N` | Same position twice | Remove duplicate `-- param:` |
| `parameter annotations must be sequential starting at $1, missing $N` | Gap in positions | Add missing `-- param: $N` |
| `invalid Go type "X" for parameter $N` | Bad type syntax | Use valid Go type |
| `parameter count mismatch: query expects N, found M` | Wrong number of params | Match annotations to SQL params |

### Result Annotation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `duplicate result annotation for column "X"` | Same column twice | Remove duplicate `-- result:` |
| `invalid Go type "X" for result column "Y"` | Bad type syntax | Use valid Go type |
| `result annotation for column 'X' not found in query results` | Column doesn't exist | Check column alias in SELECT |

### :paginated Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ORDER BY column "X" not found in SELECT list` | ORDER BY column missing | Add column to SELECT |
| `ORDER BY uses expression instead of column reference` | Complex ORDER BY | Use simple column reference |

## Runtime Errors

### Generated Error Types

skimatik generates these error types for common database errors:

```go
// Check error types (order matters - check specific errors first)
if generated.IsNotFound(err) {
    // Row not found (for :one queries)
}

if generated.IsAlreadyExists(err) {
    // Unique constraint violation
}

if generated.IsInvalidReference(err) {
    // Foreign key constraint violation
}

if generated.IsValidationError(err) {
    // Check constraint or NOT NULL violation
}

if generated.IsConnectionError(err) {
    // Database connection issues
}

if generated.IsTimeout(err) {
    // Context deadline exceeded
}

if generated.IsDatabaseError(err) {
    // Catch-all for any unexpected database errors
    // Use AFTER checking specific types above
}
```

### Error Type Reference

| Error | Cause | Check Function |
|-------|-------|----------------|
| `ErrNotFound` | No row returned for `:one` query | `IsNotFound(err)` |
| `ErrAlreadyExists` | Unique constraint violation (23505) | `IsAlreadyExists(err)` |
| `ErrInvalidReference` | Foreign key constraint violation (23503) | `IsInvalidReference(err)` |
| `ErrValidationFailed` | Check constraint violation (23514) | `IsValidationError(err)` |
| `ErrRequiredField` | NOT NULL violation (23502) | `IsValidationError(err)` |
| `ErrTimeout` | Context deadline exceeded | `IsTimeout(err)` |
| `ErrDatabaseConnection` | Connection-related errors | `IsConnectionError(err)` |
| `ErrDatabase` | Any other database error | `IsDatabaseError(err)` |

### Using DatabaseError

For detailed error information:

```go
var dbErr *generated.DatabaseError
if errors.As(err, &dbErr) {
    switch dbErr.Type {
    case generated.ErrNotFound:
        log.Printf("Not found in %s", dbErr.Operation)
    case generated.ErrAlreadyExists:
        log.Printf("Duplicate: %s", dbErr.Detail)
    case generated.ErrInvalidReference:
        log.Printf("Invalid FK: %s", dbErr.Detail)
    case generated.ErrValidationFailed, generated.ErrRequiredField:
        log.Printf("Validation error: %s", dbErr.Detail)
    case generated.ErrTimeout:
        log.Printf("Timeout during %s", dbErr.Operation)
    case generated.ErrDatabaseConnection:
        log.Printf("Connection error: %s", dbErr.Detail)
    case generated.ErrDatabase:
        log.Printf("Unexpected DB error: %v", dbErr)
    }
}
```

**DatabaseError fields:**
- `Type` - One of the error constants above
- `Operation` - The operation that failed (e.g., "create", "get", "update")
- `Entity` - The entity name (e.g., "User", "Post")
- `Detail` - Additional details from the database
- `Cause` - The underlying error (use `errors.Unwrap()` to access)

### Connection Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `connection refused` | PostgreSQL not running | Start database, check port |
| `could not connect to server` | Wrong host/port | Verify connection string |
| `password authentication failed` | Bad credentials | Check username/password |
| `database "X" does not exist` | Wrong database name | Create database or fix DSN |

### Query Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `relation "X" does not exist` | Table renamed/dropped | Regenerate after schema change |
| `column "X" does not exist` | Column renamed/dropped | Regenerate after schema change |
| `syntax error` | Invalid SQL in query file | Check SQL syntax |

## Handling Errors in Application Code

### Basic Error Handling

```go
user, err := repo.Get(ctx, userID)
if err != nil {
    if generated.IsNotFound(err) {
        return nil, ErrUserNotFound
    }
    return nil, fmt.Errorf("failed to get user: %w", err)
}
```

### Create with Duplicate Check

```go
user, err := repo.Create(ctx, params)
if err != nil {
    if generated.IsAlreadyExists(err) {
        return nil, ErrEmailTaken
    }
    return nil, fmt.Errorf("failed to create user: %w", err)
}
```

### Foreign Key Validation

```go
post, err := repo.Create(ctx, generated.CreatePostsParams{
    AuthorID: authorID,
    Title:    title,
})
if err != nil {
    if generated.IsInvalidReference(err) {
        return nil, ErrAuthorNotFound
    }
    return nil, fmt.Errorf("failed to create post: %w", err)
}
```

### Recommended Error Handling Pattern

Use a switch statement checking specific errors first, with `IsDatabaseError` as the catch-all:

```go
func (s *Service) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    user, err := s.repo.Create(ctx, generated.CreateUsersParams{
        Name:  req.Name,
        Email: req.Email,
    })
    if err != nil {
        switch {
        case generated.IsAlreadyExists(err):
            return nil, &ValidationError{Field: "email", Message: "email already registered"}
        case generated.IsValidationError(err):
            return nil, &ValidationError{Field: "unknown", Message: "invalid data"}
        case generated.IsDatabaseError(err):
            // Log the full error for debugging, return generic error to caller
            log.Printf("Database error creating user: %v", err)
            return nil, ErrInternalServer
        default:
            // Non-database error (shouldn't happen, but handle gracefully)
            return nil, fmt.Errorf("unexpected error: %w", err)
        }
    }
    return user, nil
}
```

### HTTP Error Mapping

Map database errors to HTTP status codes:

```go
func mapErrorToHTTP(err error) (int, string) {
    switch {
    case generated.IsNotFound(err):
        return 404, "Resource not found"
    case generated.IsAlreadyExists(err):
        return 409, "Resource already exists"
    case generated.IsInvalidReference(err):
        return 422, "Referenced resource does not exist"
    case generated.IsValidationError(err):
        return 400, "Invalid input data"
    case generated.IsTimeout(err):
        return 408, "Request timeout"
    case generated.IsConnectionError(err):
        return 503, "Service temporarily unavailable"
    case generated.IsDatabaseError(err):
        return 500, "Internal server error"
    default:
        return 500, "Internal server error"
    }
}
```

### Service Layer Best Practices

1. **Check specific errors first** - Order matters; `IsDatabaseError` catches everything
2. **Translate to domain errors** - Don't leak `generated` types to API layer
3. **Log unexpected errors** - Always log when hitting `IsDatabaseError` catch-all
4. **Wrap with context** - Use `fmt.Errorf("operation failed: %w", err)` for traceability
