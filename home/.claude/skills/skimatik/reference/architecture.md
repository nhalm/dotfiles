# Architecture Reference

Complete guide to the recommended architecture when using skimatik.

## Directory Structure

```
internal/
├── models/                    # Domain entities
│   ├── product.go            # Product domain model
│   ├── product_requests.go   # Service-layer request/response types
│   └── errors.go             # Domain error types
├── repository/
│   ├── generated/            # skimatik output (DO NOT EDIT)
│   │   ├── products_generated.go
│   │   ├── products_queries_generated.go
│   │   ├── pagination.go
│   │   └── errors.go
│   ├── queries/              # .sql files for custom queries
│   │   └── products.sql
│   ├── product_repository.go # Custom wrapper (YOUR code)
│   ├── helpers.go            # Shared conversion helpers
│   └── errors.go             # Repository sentinel errors
├── service/
│   ├── product_service.go    # Business logic
│   └── interfaces.go         # Repository interfaces (optional)
├── api/
│   ├── handler.go            # HTTP handler
│   ├── product_handlers.go   # Product endpoints
│   ├── requests.go           # API request types with validation
│   ├── responses.go          # API response types
│   ├── routes.go             # Route configuration
│   └── errors.go             # HTTP error translation
├── apperrors/
│   └── errors.go             # Application-wide error types
└── database/
    └── migrations/           # golang-migrate SQL files
        ├── 000001_create_products.up.sql
        └── 000001_create_products.down.sql
```

## Layer Responsibilities

### Generated Layer (DO NOT EDIT)

Skimatik generates type-safe repository code with a consistent v2 API pattern.

**Method Signature Pattern**: All generated methods require `db pgxkit.Executor` as the second parameter:

```go
// Generated CRUD methods
func (r *ProductsRepository) Create(ctx context.Context, db pgxkit.Executor, params CreateProductsParams) (*Products, error)
func (r *ProductsRepository) GetByID(ctx context.Context, db pgxkit.Executor, id string) (*Products, error)
func (r *ProductsRepository) Update(ctx context.Context, db pgxkit.Executor, params UpdateProductsParams) (*Products, error)
func (r *ProductsRepository) Delete(ctx context.Context, db pgxkit.Executor, id string) error
func (r *ProductsRepository) ListPaginated(ctx context.Context, db pgxkit.Executor, limit int, afterCursor, beforeCursor *string) (*ListProductsResult, error)

// Generated custom query methods
func (q *ProductsQueries) ListProducts(ctx context.Context, db pgxkit.Executor, active *bool, limit int, afterCursor, beforeCursor *string) ([]*Products, error)
```

The `pgxkit.Executor` interface enables both regular database operations and transaction support:
- Pass `*pgxkit.DB` for normal operations
- Pass `*pgxkit.Tx` for transactional operations

**Why this pattern?**
- Enables transaction support without changing generated method signatures
- Provides flexibility to use connection pools, direct connections, or transactions
- Allows operations to be composed within transaction boundaries

### Models Layer

Domain entities with no internal dependencies:

```go
// internal/models/product.go
type Product struct {
    ID          string
    Name        string
    Description *string
    Active      bool
    Metadata    map[string]string
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

// internal/models/product_requests.go
type CreateProductRequest struct {
    Name        string
    Description *string
    Metadata    map[string]string
}

type UpdateProductRequest struct {
    ID          string
    Name        *string  // Optional for partial updates
    Description *string
    Active      *bool
    Metadata    map[string]string
}

type ListProductsFilter struct {
    Active      *bool
    Limit       int
    AfterCursor *string
}
```

### Repository Layer

Custom repositories embed generated code, store db, and handle type conversions.

**Key v2 Change**: All generated methods require `db pgxkit.Executor` as the second parameter. Your wrapper repository stores the database connection and passes it to every generated method call.

```go
// internal/repository/product_repository.go
type ProductRepository struct {
    db *pgxkit.DB                  // Store db to pass to generated methods
    *generated.ProductsRepository  // Embed CRUD operations
    *generated.ProductsQueries     // Embed custom queries
}

func NewProductRepository(db *pgxkit.DB) *ProductRepository {
    return &ProductRepository{
        db:                 db,
        ProductsRepository: generated.NewProductsRepository(prefixedIDGenerator("prod_")),
        ProductsQueries:    generated.NewProductsQueries(),
    }
}

// Convert domain request → generated params → domain response
func (r *ProductRepository) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    // Convert to generated params
    params := generated.CreateProductsParams{
        Name:        req.Name,
        Description: req.Description,
        Metadata:    marshalMetadata(req.Metadata),
    }

    // Call embedded generated method - pass r.db as second parameter
    row, err := r.ProductsRepository.Create(ctx, r.db, params)
    if err != nil {
        return nil, translateError(err)
    }

    // Convert to domain model
    return toProduct(row), nil
}

// Update wraps generated Update method
func (r *ProductRepository) Update(ctx context.Context, req *models.UpdateProductRequest) (*models.Product, error) {
    params := generated.UpdateProductsParams{
        Id:          req.ID,
        Name:        req.Name,
        Description: req.Description,
        Active:      req.Active,
        Metadata:    marshalMetadata(req.Metadata),
    }

    // Pass r.db as second parameter
    row, err := r.ProductsRepository.Update(ctx, r.db, params)
    if err != nil {
        return nil, translateError(err)
    }

    return toProduct(row), nil
}

// GetByID wraps generated GetByID method
func (r *ProductRepository) GetByID(ctx context.Context, id string) (*models.Product, error) {
    // Pass r.db as second parameter
    row, err := r.ProductsRepository.GetByID(ctx, r.db, id)
    if err != nil {
        return nil, translateError(err)
    }

    return toProduct(row), nil
}

// Use embedded queries for complex reads
func (r *ProductRepository) ListWithFilters(ctx context.Context, filter models.ListProductsFilter) (*models.ListProductsResult, error) {
    // Pass r.db as second parameter to embedded query method
    rows, err := r.ListProducts(ctx, r.db,
        filter.Active,
        filter.Limit,
        filter.AfterCursor,
        nil, // beforeCursor
    )
    if err != nil {
        return nil, translateError(err)
    }

    return toListResult(rows, filter.Limit), nil
}
```

### Service Layer

Business logic that defines its own repository interface:

```go
// internal/service/product_service.go

// Service defines only what it needs from repository
type ProductRepository interface {
    Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error)
    Get(ctx context.Context, id string) (*models.Product, error)
    Update(ctx context.Context, req *models.UpdateProductRequest) (*models.Product, error)
    Delete(ctx context.Context, id string) error
    ListWithFilters(ctx context.Context, filter models.ListProductsFilter) (*models.ListProductsResult, error)
}

type ProductService struct {
    repo ProductRepository
}

func NewProductService(repo ProductRepository) *ProductService {
    return &ProductService{repo: repo}
}

func (s *ProductService) CreateProduct(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    // Business validation
    if req.Name == "" {
        return nil, apperrors.NewValidationError("name", "name is required")
    }

    // Business logic (e.g., defaults, transformations)

    // Delegate to repository
    product, err := s.repo.Create(ctx, req)
    if err != nil {
        if errors.Is(err, repository.ErrAlreadyExists) {
            return nil, apperrors.NewConflictError("product with this name already exists")
        }
        return nil, err
    }

    return product, nil
}
```

### API Layer

HTTP handlers that define their own service interface:

```go
// internal/api/product_handlers.go

// Handler defines only what it needs from service
type ProductService interface {
    CreateProduct(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error)
    GetProduct(ctx context.Context, id string) (*models.Product, error)
}

type Handler struct {
    products ProductService
}

func NewHandler(products ProductService) *Handler {
    return &Handler{products: products}
}

func (h *Handler) CreateProduct(w http.ResponseWriter, r *http.Request) {
    // Parse and validate API request
    var req CreateProductRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid JSON")
        return
    }

    if err := validate.Struct(req); err != nil {
        respondValidationError(w, err)
        return
    }

    // Convert API request → service request
    serviceReq := &models.CreateProductRequest{
        Name:        req.Name,
        Description: req.Description,
        Metadata:    req.Metadata,
    }

    // Call service
    product, err := h.products.CreateProduct(r.Context(), serviceReq)
    if err != nil {
        handleServiceError(w, err)
        return
    }

    // Convert domain → API response
    respondJSON(w, http.StatusCreated, toProductResponse(product))
}
```

## Type Conversion Strategy

Three model types per entity, converted at layer boundaries:

```
API Request → Service Request → Generated Params
                                      ↓
API Response ← Domain Model ← Generated Row
```

```go
// API types (with validation tags)
type CreateProductRequest struct {
    Name        string            `json:"name" validate:"required,max=255"`
    Description *string           `json:"description" validate:"omitempty,max=1000"`
    Metadata    map[string]string `json:"metadata"`
}

// Domain types (business logic)
type Product struct {
    ID          string
    Name        string
    // ...
}

// Generated types (database schema)
type Products struct {
    Id          string
    Name        string
    // ...
}
```

## Error Handling Flow

```
Repository: generated error → sentinel error (ErrNotFound, ErrAlreadyExists)
     ↓
Service: sentinel error → domain error (apperrors.NotFoundError)
     ↓
API: domain error → HTTP status code + JSON response
```

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

// internal/apperrors/errors.go
type NotFoundError struct {
    Resource string
    ID       string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s with id %s not found", e.Resource, e.ID)
}

// internal/api/errors.go
func handleServiceError(w http.ResponseWriter, err error) {
    var notFound *apperrors.NotFoundError
    if errors.As(err, &notFound) {
        respondError(w, http.StatusNotFound, err.Error())
        return
    }

    var conflict *apperrors.ConflictError
    if errors.As(err, &conflict) {
        respondError(w, http.StatusConflict, err.Error())
        return
    }

    // Log unexpected error, return generic message
    slog.Error("unexpected error", "error", err)
    respondError(w, http.StatusInternalServerError, "internal server error")
}
```

## Dependency Injection (Manual Wiring)

No DI framework - explicit constructor wiring:

```go
// cmd/myapp/cmd/serve.go
func runServer(cfg *config.Config) error {
    // Database
    db := pgxkit.NewDB()
    if err := db.Connect(ctx, cfg.DatabaseURL); err != nil {
        return err
    }
    defer db.Shutdown(ctx)

    // Repositories
    productRepo := repository.NewProductRepository(db)

    // Services
    productSvc := service.NewProductService(productRepo)

    // Handlers
    handler := api.NewHandler(productSvc)

    // Server
    srv := &http.Server{
        Addr:    fmt.Sprintf(":%d", cfg.Port),
        Handler: handler.Routes(),
    }

    return srv.ListenAndServe()
}
```

## Testing Strategy

Each layer is independently testable via interfaces:

```go
// Service test - mock repository
type mockProductRepo struct {
    createFn func(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error)
}

func (m *mockProductRepo) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    return m.createFn(ctx, req)
}

func TestProductService_Create(t *testing.T) {
    repo := &mockProductRepo{
        createFn: func(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
            return &models.Product{ID: "prod_123", Name: req.Name}, nil
        },
    }

    svc := service.NewProductService(repo)
    product, err := svc.CreateProduct(ctx, &models.CreateProductRequest{Name: "Test"})

    require.NoError(t, err)
    assert.Equal(t, "Test", product.Name)
}
```

## ID Generation

Custom ID prefixes for entity identification:

```go
// internal/repository/helpers.go
func prefixedIDGenerator(prefix string) func() uuid.UUID {
    return func() uuid.UUID {
        id := uuid.Must(uuid.NewV7())
        // Note: This returns UUID, but you might store as string with prefix
        return id
    }
}

// Or for string IDs with prefix:
func (r *ProductRepository) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    id := fmt.Sprintf("prod_%s", uuid.Must(uuid.NewV7()).String())
    // ...
}
```

## Transaction Support

All generated methods accept `pgxkit.Executor`, which can be either `*pgxkit.DB` or `*pgxkit.Tx`. This enables transaction support without code changes.

```go
// Wrap multiple operations in a transaction
func (r *ProductRepository) CreateWithRelated(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    var product *models.Product

    // Begin transaction
    err := r.db.InTx(ctx, func(tx pgxkit.Executor) error {
        // Create product - pass tx instead of r.db
        params := generated.CreateProductsParams{
            Name:        req.Name,
            Description: req.Description,
            Metadata:    marshalMetadata(req.Metadata),
        }

        row, err := r.ProductsRepository.Create(ctx, tx, params)
        if err != nil {
            return err
        }
        product = toProduct(row)

        // Create related records - pass same tx
        if err := r.createRelatedRecords(ctx, tx, product.ID); err != nil {
            return err // Transaction rolls back
        }

        return nil // Transaction commits
    })

    if err != nil {
        return nil, translateError(err)
    }

    return product, nil
}

func (r *ProductRepository) createRelatedRecords(ctx context.Context, tx pgxkit.Executor, productID string) error {
    // All method calls use the same tx
    params := generated.CreateRelatedParams{ProductID: productID}
    _, err := r.RelatedRepository.Create(ctx, tx, params)
    return err
}
```

## Soft Deletes

Handle soft deletes in queries, not application code:

```sql
-- queries/products.sql

-- name: GetProductByID :one
SELECT id, name, description, active, metadata, created_at, updated_at
FROM products
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListProducts :many
SELECT id, name, description, active, metadata, created_at, updated_at
FROM products
WHERE deleted_at IS NULL
  AND ($1::boolean IS NULL OR active = $1)
ORDER BY id ASC
LIMIT $2;

-- name: SoftDeleteProduct :exec
UPDATE products SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL;
```

```go
// Wrapper method that uses soft delete query
func (r *ProductRepository) Delete(ctx context.Context, id string) error {
    // Pass r.db as second parameter to generated query method
    return r.SoftDeleteProduct(ctx, r.db, id)
}
```

## Metadata/JSON Handling

Marshal/unmarshal JSON in repository layer:

```go
// internal/repository/helpers.go
func marshalMetadata(m map[string]string) json.RawMessage {
    if m == nil {
        return nil
    }
    data, _ := json.Marshal(m)
    return data
}

func unmarshalMetadata(data json.RawMessage) map[string]string {
    if data == nil {
        return nil
    }
    var m map[string]string
    json.Unmarshal(data, &m)
    return m
}
```
