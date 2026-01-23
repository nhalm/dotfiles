# Generated Code Reference

How to use skimatik-generated repositories and queries.

> **Note:** See [SKILL.md](../SKILL.md) for core principles and architecture overview.

## Generated File Structure

```
repository/generated/
├── users_generated.go          # CRUD repository for users table
├── posts_generated.go          # CRUD repository for posts table
├── users_queries_generated.go  # Custom queries from users.sql
├── posts_queries_generated.go  # Custom queries from posts.sql
├── pagination.go               # Pagination types and helpers
├── errors.go                   # Error types and helpers
├── database_operations.go      # Shared database utilities
├── retry_operations.go         # Retry logic utilities
└── id_generators.go            # UUID v7 generator
```

## Dependencies

Generated code requires:

```go
import (
    "github.com/nhalm/pgxkit"      // Database connection abstraction
    "github.com/google/uuid"        // UUID types
    "github.com/jackc/pgx/v5"       // PostgreSQL driver (transitive)
)
```

## Table Repositories

### Initialization

```go
import (
    "github.com/nhalm/pgxkit"
    "yourproject/repository/generated"
)

// Connect to database
db := pgxkit.NewDB()
err := db.Connect(ctx, "postgres://user:pass@localhost:5432/dbname")
if err != nil {
    log.Fatal(err)
}
defer db.Shutdown(ctx)

// Create repository (nil = use default UUID v7 generator)
repo := generated.NewUsersRepository(nil)

// Or with custom ID generator
customIDGen := func() uuid.UUID {
    return uuid.New()  // UUID v4 instead
}
repo := generated.NewUsersRepository(customIDGen)

// All methods require db parameter - pass db to each call
user, err := repo.Create(ctx, db, params)
```

### CRUD Operations

All methods require `db pgxkit.Executor` as the second parameter after context.

**Create:**
```go
user, err := repo.Create(ctx, db, generated.CreateUsersParams{
    Name:  "John Doe",
    Email: "john@example.com",
    Bio:   nil,  // Nullable field
})
if err != nil {
    if generated.IsAlreadyExists(err) {
        // Handle duplicate
    }
    return err
}
fmt.Printf("Created user: %s\n", user.Id)
```

**Get by ID:**
```go
user, err := repo.Get(ctx, db, userID)
if err != nil {
    if generated.IsNotFound(err) {
        // Handle not found
    }
    return err
}
```

**Update:**
```go
user, err := repo.Update(ctx, db, userID, generated.UpdateUsersParams{
    Name: "Jane Doe",
    Bio:  &newBio,  // Set nullable field
})
```

**Delete:**
```go
err := repo.Delete(ctx, db, userID)
```

**List all:**
```go
users, err := repo.List(ctx, db)
```

**Paginated list:**
```go
result, err := repo.ListPaginated(ctx, db, generated.PaginationParams{
    Limit:   20,
    OrderBy: "created_at",
})

fmt.Printf("Users: %d\n", len(result.Items))
fmt.Printf("Has more: %v\n", result.HasMore)
fmt.Printf("Has previous: %v\n", result.HasPrevious)

// Next page
if result.HasMore {
    next, err := repo.ListPaginated(ctx, db, generated.PaginationParams{
        Limit:      20,
        OrderBy:    "created_at",
        NextCursor: result.NextCursor,
    })
}

// Previous page
if result.HasPrevious {
    prev, err := repo.ListPaginated(ctx, db, generated.PaginationParams{
        Limit:        20,
        OrderBy:      "created_at",
        BeforeCursor: result.BeforeCursor,
    })
}
```

## Custom Queries

### Initialization

```go
queries := generated.NewUsersQueries()  // No parameters
```

### Using Generated Query Functions

From this SQL:
```sql
-- name: GetUserByEmail :one
SELECT id, name, email FROM users WHERE email = $1;

-- name: GetActiveUsers :many
SELECT id, name, email FROM users WHERE is_active = true LIMIT $1;

-- name: DeactivateUser :exec
UPDATE users SET is_active = false WHERE id = $1;
```

Generated usage (all methods require `db` parameter):
```go
// :one query - returns pointer and error
user, err := queries.GetUserByEmail(ctx, db, "john@example.com")
if generated.IsNotFound(err) {
    // Handle not found
}

// :many query - returns slice and error
users, err := queries.GetActiveUsers(ctx, db, 10)
// Empty slice if no results, not error

// :exec query - returns error only
err := queries.DeactivateUser(ctx, db, userID)
```

### Paginated Queries

Use `:paginated` query type with ORDER BY:
```sql
-- name: GetRecentPosts :paginated
SELECT id, title, created_at FROM posts
WHERE is_published = true
ORDER BY created_at DESC
```

Usage (all methods require `db` parameter):
```go
// Regular version - all results
posts, err := queries.GetRecentPosts(ctx, db)

// Paginated version - bidirectional cursor pagination
result, err := queries.GetRecentPostsPaginated(ctx, db, generated.PaginationParams{
    Limit: 20,
})

// Next page (forward)
if result.HasMore {
    next, err := queries.GetRecentPostsPaginated(ctx, db, generated.PaginationParams{
        Limit:      20,
        NextCursor: result.NextCursor,
    })
}

// Previous page (backward)
if result.HasPrevious {
    prev, err := queries.GetRecentPostsPaginated(ctx, db, generated.PaginationParams{
        Limit:        20,
        BeforeCursor: result.BeforeCursor,
    })
}
```

## Transactions

Generated repositories work with transactions by passing `tx` to methods:

```go
// Start transaction
tx, err := db.Begin(ctx)
if err != nil {
    return err
}
defer tx.Rollback(ctx)  // Rollback if not committed

// Create repositories (constructor doesn't take db/tx)
userRepo := generated.NewUsersRepository(nil)
postRepo := generated.NewPostsRepository(nil)

// Perform operations - pass tx to each method
user, err := userRepo.Create(ctx, tx, userParams)
if err != nil {
    return err  // Rollback happens via defer
}

post, err := postRepo.Create(ctx, tx, generated.CreatePostsParams{
    AuthorID: user.Id,
    Title:    "My Post",
})
if err != nil {
    return err
}

// Commit transaction
return tx.Commit(ctx)
```

## Repository Embedding (Required Pattern)

**Never use generated repositories directly.** Always embed in custom types:

```go
// internal/repository/product_repository.go
type ProductRepository struct {
    db *pgxkit.DB                  // Store db to pass to generated methods
    *generated.ProductsRepository  // Embed for CRUD
    *generated.ProductsQueries     // Embed for custom queries
}

func NewProductRepository(db *pgxkit.DB) *ProductRepository {
    return &ProductRepository{
        db:                 db,
        ProductsRepository: generated.NewProductsRepository(nil),  // nil = default UUID v7
        ProductsQueries:    generated.NewProductsQueries(),
    }
}

// Convert domain types → generated types → domain types
func (r *ProductRepository) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    // Convert to generated params
    params := generated.CreateProductsParams{
        Name:        req.Name,
        Description: req.Description,
        Metadata:    marshalMetadata(req.Metadata),
    }

    // Call embedded method - pass r.db as second parameter
    row, err := r.ProductsRepository.Create(ctx, r.db, params)
    if err != nil {
        return nil, translateError(err)
    }

    // Convert to domain model
    return toProduct(row), nil
}

// Use queries for complex reads
func (r *ProductRepository) GetByEmail(ctx context.Context, email string) (*models.Product, error) {
    row, err := r.GetProductByEmail(ctx, r.db, email)  // Embedded method - pass r.db
    if err != nil {
        return nil, translateError(err)
    }
    return toProduct(row), nil
}
```

### Service Depends on Interface

Services define their own interface - not the concrete repository:

```go
// internal/service/product_service.go

// Service defines only the methods it needs
type ProductRepository interface {
    Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error)
    Get(ctx context.Context, id string) (*models.Product, error)
    Update(ctx context.Context, req *models.UpdateProductRequest) (*models.Product, error)
    Delete(ctx context.Context, id string) error
}

type ProductService struct {
    repo ProductRepository  // Interface, NOT *repository.ProductRepository
}

func NewProductService(repo ProductRepository) *ProductService {
    return &ProductService{repo: repo}
}
```

### Error Translation

Translate generated errors to repository sentinel errors:

```go
// internal/repository/errors.go
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
)

func translateError(err error) error {
    if generated.IsNotFound(err) {
        return ErrNotFound
    }
    if generated.IsAlreadyExists(err) {
        return ErrAlreadyExists
    }
    return err
}
```

See [reference/architecture.md](architecture.md) for complete architecture patterns.

## Error Handling

### Error Check Functions

```go
if generated.IsNotFound(err) {
    // Row not found for :one query
}

if generated.IsAlreadyExists(err) {
    // Unique constraint violation
}

if generated.IsInvalidReference(err) {
    // Foreign key constraint violation
}
```

### DatabaseError Type

```go
var dbErr *generated.DatabaseError
if errors.As(err, &dbErr) {
    log.Printf("Operation: %s", dbErr.Operation)
    log.Printf("Entity: %s", dbErr.Entity)
    log.Printf("Type: %v", dbErr.Type)
    log.Printf("Detail: %s", dbErr.Detail)
}
```

## Pagination Types

```go
type PaginationParams struct {
    Limit        int    // Max items per page
    OrderBy      string // Column to sort by (table repos)
    NextCursor   string // Cursor for next page (empty string = first page)
    BeforeCursor string // Cursor for previous page (table repos only)
}

type PaginationResult[T any] struct {
    Items        []T
    NextCursor   string // Empty if no more pages
    BeforeCursor string // Table repos only
    HasMore      bool
    HasPrevious  bool   // Table repos only
}
```

Note: Cursor fields use `string` with `omitempty` JSON tags, not `*string` pointers.

## Generated Struct Tags

All generated structs include JSON and DB tags:

```go
type Users struct {
    Id        uuid.UUID  `json:"id" db:"id"`
    Name      string     `json:"name" db:"name"`
    Email     string     `json:"email" db:"email"`
    Bio       *string    `json:"bio" db:"bio"`
    CreatedAt time.Time  `json:"created_at" db:"created_at"`
}
```

## Best Practices

1. **Never edit generated files** - They're overwritten on regenerate
2. **Never write raw SQL in Go** - All queries go in `.sql` files
3. **Always embed repositories** - In custom types with type conversion
4. **Services use interfaces** - Define only methods they need
5. **Translate errors at boundaries** - Generated → sentinel → domain
6. **Regenerate after schema changes** - Keep code in sync

See [reference/architecture.md](architecture.md) for complete patterns.
