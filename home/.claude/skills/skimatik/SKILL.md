---
name: skimatik
description: Database-first Go code generator for PostgreSQL. Triggers when writing .sql query files with skimatik annotations (-- name:, -- param:, -- result:), configuring skimatik.yaml, debugging skimatik parsing errors, or understanding generated repository patterns. Do NOT trigger for general SQL writing without skimatik context or PostgreSQL administration.
---

# skimatik - Database-First Go Code Generator

skimatik generates type-safe Go repository code from PostgreSQL schemas and annotated SQL query files.

## Core Principles

1. **All SQL lives in `.sql` files** - NEVER write raw SQL strings in Go code. Every query goes in a `.sql` file with skimatik annotations.

2. **Embed, don't use directly** - Don't use generated repositories directly in services. Embed them in custom repository types that add business logic.

3. **Generated code is read-only** - Never edit `*_generated.go` files. They will be overwritten on regeneration.

4. **Services depend on interfaces** - Services define their own repository interfaces, not concrete types.

## Architecture Overview

```
internal/
├── models/              # Domain entities (no internal imports)
├── repository/
│   ├── generated/       # skimatik output (DO NOT EDIT)
│   ├── queries/         # .sql files for custom queries
│   ├── product_repository.go  # Custom wrapper embedding generated
│   └── errors.go        # Repository error types
├── service/             # Business logic (defines repo interfaces)
└── api/                 # HTTP handlers (defines service interfaces)
```

**Dependency flow:** `models ← repository ← service ← api`

## What skimatik Generates

1. **Table Repositories** - CRUD operations for each table
   - `NewUsersRepository(db, idGen)` → Create, Get, Update, Delete, List, ListPaginated
   - Also generates retry variants: CreateWithRetry, GetWithRetry, etc.

2. **Query Handlers** - Custom queries from `.sql` files
   - `NewUsersQueries(db)` → Your custom query methods

## Quick Reference

```sql
-- name: FunctionName :return_type   -- Required
-- param: $1 param_name go_type      -- Optional: override parameter type
-- result: column_name go_type       -- Optional: override result type
```

**Return types:** `:one` (single row), `:many` (slice), `:paginated` (bidirectional cursor pagination), `:exec` (no return)

## Error Helper Functions

Generated code includes these error detection helpers (check specific errors before catch-all):

```go
generated.IsNotFound(err)         // Row not found
generated.IsAlreadyExists(err)    // Unique constraint violation
generated.IsInvalidReference(err) // Foreign key violation
generated.IsValidationError(err)  // Check/NOT NULL constraint
generated.IsConnectionError(err)  // Database connection issues
generated.IsTimeout(err)          // Context deadline exceeded
generated.IsDatabaseError(err)    // Catch-all for any database error
```

**Order matters:** Check specific errors first, use `IsDatabaseError` as the final catch-all.

## When to Load Which File

| Task | Load This File |
|------|----------------|
| Writing a new SQL query | [patterns/annotations.md](patterns/annotations.md) |
| Complex SQL (CTEs, joins, pagination) | [patterns/sql-patterns.md](patterns/sql-patterns.md) |
| Type mismatch or custom types | [reference/type-mapping.md](reference/type-mapping.md) |
| Setting up or configuring skimatik | [reference/configuration.md](reference/configuration.md) |
| Generation or runtime errors | [reference/errors.md](reference/errors.md) |
| Error handling in service/API layers | [reference/errors.md](reference/errors.md) |
| Building repository/service/API layers | [reference/architecture.md](reference/architecture.md) |
| Using generated repositories in Go | [reference/generated-code.md](reference/generated-code.md) |
| Code review or debugging patterns | [patterns/anti-patterns.md](patterns/anti-patterns.md) |
| Retry logic for transient failures | [reference/retry-methods.md](reference/retry-methods.md) |

## Agent Decision Tree

### First-Time Setup
1. [reference/configuration.md](reference/configuration.md) - Configure skimatik.yaml
2. [reference/architecture.md](reference/architecture.md) - Understand layer structure
3. [patterns/annotations.md](patterns/annotations.md) - Write first query

### Writing Queries
1. [patterns/annotations.md](patterns/annotations.md) - Start here
2. [patterns/sql-patterns.md](patterns/sql-patterns.md) - For CTEs, joins, pagination
3. [reference/type-mapping.md](reference/type-mapping.md) - If type issues arise
4. [patterns/anti-patterns.md](patterns/anti-patterns.md) - Validate before finalizing

### Debugging
1. [reference/errors.md](reference/errors.md) - Check known errors first
2. [patterns/anti-patterns.md](patterns/anti-patterns.md) - Common mistakes
3. [reference/configuration.md](reference/configuration.md) - For generation failures

### Error Handling in Application Code
1. [reference/errors.md](reference/errors.md) - Error helper functions and patterns

### Code Review
Load [patterns/anti-patterns.md](patterns/anti-patterns.md) - Comprehensive checklist

## Documentation Files

- **[reference/architecture.md](reference/architecture.md)** - Full architecture patterns
- **[patterns/annotations.md](patterns/annotations.md)** - Annotation syntax
- **[patterns/sql-patterns.md](patterns/sql-patterns.md)** - SQL query patterns
- **[patterns/anti-patterns.md](patterns/anti-patterns.md)** - What NOT to do
- **[reference/type-mapping.md](reference/type-mapping.md)** - PostgreSQL to Go types
- **[reference/configuration.md](reference/configuration.md)** - skimatik.yaml options
- **[reference/errors.md](reference/errors.md)** - Error handling
- **[reference/generated-code.md](reference/generated-code.md)** - Using generated code
- **[reference/retry-methods.md](reference/retry-methods.md)** - Retry logic for transient failures

## Correct Usage Pattern

```go
// 1. Custom repository embeds both generated types
type ProductRepository struct {
    *generated.ProductsRepository  // CRUD operations
    *generated.ProductsQueries     // Custom queries
}

// 2. Service defines interface it needs (not full repo)
type ProductRepository interface {
    Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error)
    Get(ctx context.Context, id string) (*models.Product, error)
}

type ProductService struct {
    repo ProductRepository  // Interface, not concrete type
}

// 3. Wiring in main/serve.go
productRepo := repository.NewProductRepository(db)
productSvc := service.NewProductService(productRepo)
handler := api.NewHandler(productSvc)
```
