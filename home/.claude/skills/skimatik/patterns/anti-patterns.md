# Anti-Patterns

Common mistakes to avoid when using skimatik.

## Architecture Anti-Patterns

### Writing Raw SQL in Go Code

**NEVER write SQL strings in Go code.** All queries go in `.sql` files:

```go
// WRONG - raw SQL in Go
rows, err := db.Query(ctx, "SELECT id, name FROM users WHERE email = $1", email)

// WRONG - even for "simple" queries
db.Exec(ctx, "UPDATE users SET last_login = NOW() WHERE id = $1", id)

// CORRECT - add query to .sql file and regenerate
user, err := queries.GetUserByEmail(ctx, email)
err := queries.UpdateLastLogin(ctx, id)
```

### Using Generated Repos Directly

**Don't inject generated repositories directly into services.** Embed them in your own types:

```go
// WRONG - direct usage
type UserService struct {
    repo *generated.UsersRepository
}

func (s *UserService) GetUser(ctx context.Context, id uuid.UUID) (*User, error) {
    return s.repo.Get(ctx, id)  // No place for business logic
}

// CORRECT - embed in wrapper
type UserRepository struct {
    *generated.UsersRepository
    *generated.UsersQueries
}

type UserService struct {
    repo *UserRepository
}

func (s *UserService) GetUser(ctx context.Context, id uuid.UUID) (*User, error) {
    user, err := s.repo.Get(ctx, id)
    if err != nil {
        return nil, err
    }
    // Business logic, validation, transformation
    return mapToUser(user), nil
}
```

**Why this works:**
- Embedding preserves all generated methods (Get, Create, Update, etc.)
- Your wrapper can add business logic alongside generated methods
- Type conversion happens in YOUR code, keeping generated code stable
- Services depend on your wrapper, enabling mocking and testing

### Editing Generated Files

**Never modify `*_generated.go` files.** They will be overwritten:

```go
// WRONG - editing generated file
// In users_generated.go (DON'T DO THIS)
func (r *UsersRepository) Get(ctx context.Context, id uuid.UUID) (*Users, error) {
    // Adding custom logic here WILL BE LOST
}

// CORRECT - add to your wrapper
// In repository/user_repository.go (your file)
func (r *UserRepository) GetWithPermissionCheck(ctx context.Context, id uuid.UUID, requesterID uuid.UUID) (*Users, error) {
    // Custom logic in YOUR file
}
```

### Service Depends on Concrete Repository

**Services should define their own interface**, not depend on concrete types:

```go
// WRONG - depends on concrete repository
type ProductService struct {
    repo *repository.ProductRepository  // Concrete type
}

// WRONG - imports generated types in service
import "yourproject/repository/generated"

func (s *ProductService) Create(ctx context.Context, name string) (*generated.Products, error) {
    return s.repo.Create(ctx, generated.CreateProductsParams{Name: name})
}

// CORRECT - service defines its own interface
type ProductRepository interface {
    Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error)
    Get(ctx context.Context, id string) (*models.Product, error)
}

type ProductService struct {
    repo ProductRepository  // Interface defined in service package
}

func (s *ProductService) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    // Business validation
    if req.Name == "" {
        return nil, ErrNameRequired
    }
    return s.repo.Create(ctx, req)
}
```

**Why?**
- Enables mocking for tests
- Loose coupling between layers
- Service controls its contract
- No generated types leak into business logic

### Exposing Generated Types

**Generated types should not leak outside repository layer:**

```go
// WRONG - generated type in API response
func (h *Handler) GetProduct(w http.ResponseWriter, r *http.Request) {
    product, _ := h.repo.Get(ctx, id)
    json.NewEncoder(w).Encode(product)  // Exposes generated.Products
}

// WRONG - generated params in service interface
type ProductService interface {
    Create(ctx context.Context, params generated.CreateProductsParams) (*generated.Products, error)
}

// CORRECT - domain types at all layer boundaries
// internal/models/product.go
type Product struct {
    ID   string
    Name string
}

type CreateProductRequest struct {
    Name string
}

// Repository converts generated ↔ domain
// Service uses domain types
// API converts domain ↔ API types
```

**Why this works:**
- Generated types can change on regeneration; domain types are stable
- API can evolve independently of database schema
- Enables validation and transformation at each boundary
- Testing is simpler with domain types (no generated imports)

### Skipping Type Conversion

**Repository must convert between domain and generated types:**

```go
// WRONG - passing through without conversion
func (r *ProductRepository) Create(ctx context.Context, req *models.CreateProductRequest) (*generated.Products, error) {
    return r.ProductsRepository.Create(ctx, generated.CreateProductsParams{
        Name: req.Name,
    })
    // Returns generated type directly!
}

// CORRECT - convert in both directions
func (r *ProductRepository) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    // Convert domain → generated
    params := generated.CreateProductsParams{
        Name:        req.Name,
        Description: req.Description,
    }

    row, err := r.ProductsRepository.Create(ctx, params)
    if err != nil {
        return nil, translateError(err)
    }

    // Convert generated → domain
    return &models.Product{
        ID:          row.Id,
        Name:        row.Name,
        Description: row.Description,
    }, nil
}
```

**Why this works:**
- Repository is the ONLY place that knows about generated types
- Error translation converts database errors to domain errors
- Service and API layers never import `generated` package
- Schema changes only affect repository conversion code

## Annotation Errors

### Missing Name Annotation

```sql
-- WRONG: No name annotation
SELECT id, name FROM users WHERE id = $1;

-- CORRECT:
-- name: GetUserByID :one
SELECT id, name FROM users WHERE id = $1;
```

### Invalid Function Names

```sql
-- WRONG: Hyphens not allowed
-- name: get-user-by-id :one

-- WRONG: Starts with number
-- name: 1GetUser :one

-- WRONG: Spaces
-- name: Get User :one

-- CORRECT: PascalCase
-- name: GetUserByID :one
```

### Wrong Return Type

```sql
-- WRONG: SELECT with :exec
-- name: CountUsers :exec
SELECT COUNT(*) FROM users;

-- CORRECT: Use :one for SELECT returning single row
-- name: CountUsers :one
SELECT COUNT(*) as total FROM users;
```

```sql
-- WRONG: :one for query that may return multiple rows
-- name: GetUsersByName :one
SELECT * FROM users WHERE name LIKE $1;

-- CORRECT: Use :many
-- name: GetUsersByName :many
SELECT * FROM users WHERE name LIKE $1;
```

### Parameter Position Gaps

```sql
-- WRONG: Gap in positions (missing $2)
-- name: SearchUsers :many
-- param: $1 name string
-- param: $3 limit int
SELECT * FROM users WHERE name = $1 LIMIT $3;

-- CORRECT: Sequential positions
-- name: SearchUsers :many
-- param: $1 name string
-- param: $2 limit int
SELECT * FROM users WHERE name = $1 LIMIT $2;
```

## Pagination Errors

### Missing ORDER BY in :paginated

```sql
-- WRONG: :paginated requires ORDER BY
-- name: GetPosts :paginated
SELECT id, title, created_at
FROM posts;

-- CORRECT: Include ORDER BY clause
-- name: GetPosts :paginated
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC;
```

### ORDER BY column not in SELECT

```sql
-- WRONG: ORDER BY column must be in SELECT list
-- name: GetPosts :paginated
SELECT id, title FROM posts
ORDER BY created_at DESC;  -- created_at not in SELECT!

-- CORRECT: Include ORDER BY column in SELECT
-- name: GetPosts :paginated
SELECT id, title, created_at FROM posts
ORDER BY created_at DESC;
```

### Complex ORDER BY expressions

```sql
-- WRONG: ORDER BY expressions not supported
-- name: GetUsers :paginated
SELECT id, name FROM users
ORDER BY LOWER(name);  -- Expression not supported!

-- CORRECT: Use simple column reference
-- name: GetUsers :paginated
SELECT id, name, LOWER(name) as name_lower FROM users
ORDER BY name;
```

## Type Annotation Mistakes

### Unnecessary Annotations

```sql
-- UNNECESSARY: skimatik auto-detects from schema
-- name: GetUser :one
-- param: $1 id uuid.UUID          -- Remove: obvious from column type
-- result: name string             -- Remove: obvious from column type
-- result: email string            -- Remove: obvious from column type
SELECT id, name, email FROM users WHERE id = $1;

-- CORRECT: Only annotate what's needed
-- name: GetUser :one
SELECT id, name, email FROM users WHERE id = $1;
```

### Forgetting Nullable for LEFT JOIN

```sql
-- WRONG: LEFT JOIN columns may be NULL
-- name: GetPostWithAuthor :one
SELECT p.id, p.title, u.name as author_name
FROM posts p
LEFT JOIN users u ON p.author_id = u.id
WHERE p.id = $1;

-- CORRECT: Mark LEFT JOIN columns as nullable
-- name: GetPostWithAuthor :one
-- result: author_name *string
SELECT p.id, p.title, u.name as author_name
FROM posts p
LEFT JOIN users u ON p.author_id = u.id
WHERE p.id = $1;
```

### Forgetting Nullable for Aggregates

```sql
-- WRONG: AVG/SUM/MAX/MIN can return NULL on empty set
-- name: GetStats :one
SELECT AVG(score) as avg_score, MAX(score) as max_score
FROM scores WHERE user_id = $1;

-- CORRECT: Mark as nullable
-- name: GetStats :one
-- result: avg_score *float64
-- result: max_score *int
SELECT AVG(score) as avg_score, MAX(score) as max_score
FROM scores WHERE user_id = $1;
```

## SQL Mistakes

### SELECT * (Bad Practice)

```sql
-- AVOID: SELECT * makes schema changes break silently
-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- BETTER: Explicit columns
-- name: GetUser :one
SELECT id, name, email, created_at FROM users WHERE id = $1;
```

### Missing LIMIT on :many

```sql
-- RISKY: No limit on potentially large result set
-- name: GetAllUsers :many
SELECT id, name, email FROM users;

-- SAFER: Add reasonable limit or use pagination
-- name: GetAllUsers :many
SELECT id, name, email FROM users LIMIT 1000;

-- BEST: Use :paginated for large result sets
-- name: GetAllUsers :paginated
SELECT id, name, email FROM users
ORDER BY id ASC;
```

### Nullable Parameter Without IS NULL Check

```sql
-- WRONG: NULL parameter won't match anything
-- name: SearchUsers :many
-- param: $1 name_filter *string
SELECT * FROM users WHERE name = $1;  -- NULL = NULL is never true!

-- CORRECT: Use IS NULL OR pattern
-- name: SearchUsers :many
-- param: $1 name_filter *string
SELECT * FROM users WHERE ($1::text IS NULL OR name = $1);
```

## Naming Conflicts

### Duplicate Query Names

```sql
-- File: users.sql
-- name: GetByID :one
SELECT * FROM users WHERE id = $1;

-- File: posts.sql
-- name: GetByID :one  -- WRONG: Conflicts with users.sql!
SELECT * FROM posts WHERE id = $1;

-- CORRECT: Use unique names
-- File: users.sql
-- name: GetUserByID :one

-- File: posts.sql
-- name: GetPostByID :one
```

## Performance Anti-Patterns

### LIKE with Leading Wildcard

```sql
-- SLOW: Can't use index
-- name: SearchUsers :many
SELECT * FROM users WHERE name LIKE '%' || $1 || '%';

-- FASTER: Use trailing wildcard only (can use index)
-- name: SearchUsers :many
SELECT * FROM users WHERE name LIKE $1 || '%';

-- OR: Use full-text search for complex searches
```

### Unindexed ORDER BY Column

```sql
-- SLOW: ORDER BY on unindexed column
-- name: GetPosts :paginated
SELECT id, title, some_unindexed_column FROM posts
ORDER BY some_unindexed_column DESC;

-- BETTER: Use indexed columns for ORDER BY
-- name: GetPosts :paginated
SELECT id, title, created_at FROM posts
ORDER BY created_at DESC;  -- created_at should be indexed
```
