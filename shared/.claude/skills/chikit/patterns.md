# Patterns & Anti-Patterns

Integration patterns, error handling deep dive, and common mistakes.

---

## Structured Error Handling Deep Dive

**This is a key architectural decision in chikit.**

### Single Response Point

The `Handler()` middleware centralizes ALL response writing. Handlers and middleware **never write to ResponseWriter directly**. Instead:

1. Call `chikit.SetError(r, err)` or `chikit.SetResponse(r, status, body)`
2. Return immediately
3. Handler writes the JSON response in its deferred cleanup

```go
// CORRECT - set and return
func handler(w http.ResponseWriter, r *http.Request) {
    user, err := getUser(r)
    if err != nil {
        chikit.SetError(r, chikit.ErrNotFound.With("User not found"))
        return  // MUST return after SetError
    }
    chikit.SetResponse(r, http.StatusOK, user)
}

// WRONG - writing directly
func handler(w http.ResponseWriter, r *http.Request) {
    http.Error(w, "Not found", 404)  // Bypasses Handler, inconsistent format
}
```

### APIError Struct

```go
type APIError struct {
    Type    string       // Error category (e.g., "auth_error", "validation_error")
    Code    string       // Specific code (e.g., "unauthorized", "invalid_request")
    Message string       // Human-readable message
    Param   string       // Field name for validation errors
    Errors  []FieldError // Multiple field errors
    Status  int          // HTTP status (not serialized)
}
```

### JSON Output Format

```json
{
  "error": {
    "type": "validation_error",
    "code": "invalid_request",
    "message": "Validation failed",
    "errors": [
      {"param": "email", "code": "required", "message": "Email is required"},
      {"param": "age", "code": "min", "message": "Age must be at least 18"}
    ]
  }
}
```

### Sentinel Errors

15 pre-defined errors cover common HTTP statuses. Use `.With()` to customize the message while preserving type/code:

```go
chikit.ErrNotFound.With("User not found")           // Custom message
chikit.ErrBadRequest.WithParam("Invalid format", "email")  // With field name
```

### errors.Is() Support

Sentinel errors implement `errors.Is()` comparing Type and Code:

```go
if errors.Is(err, chikit.ErrNotFound) {
    // Handle not found case
}
```

### Multiple Field Validation Errors

```go
chikit.SetError(r, chikit.NewValidationError([]chikit.FieldError{
    {Param: "email", Code: "required", Message: "Email is required"},
    {Param: "password", Code: "min", Message: "Password must be at least 8 characters"},
}))
```

---

## Error Flow Patterns

### Always Return After SetError

**Critical pattern:** After calling `SetError`, the handler must return immediately. Otherwise, execution continues and may overwrite the error or cause unexpected behavior.

```go
if err != nil {
    chikit.SetError(r, chikit.ErrInternal)
    return  // MUST return
}
// Code here runs if you forget to return
```

### chikit.JSON / chikit.Query Pattern

These functions return `bool` - if `false`, error is already set:

```go
var req CreateUserRequest
if !chikit.JSON(r, &req) {
    return  // Error already set, just return
}
// Use req safely here
```

### First Error Wins

Once `SetError` is called, subsequent calls are no-ops (state already has an error). This means the first error in the middleware chain is the one returned:

```go
chikit.SetError(r, chikit.ErrBadRequest)   // This wins
chikit.SetError(r, chikit.ErrInternal)     // Ignored (state already has error)
```

### State Freezing After Timeout

When a timeout fires, the state is frozen. Subsequent calls to `SetError`, `SetResponse`, and `SetHeader` become no-ops:

```go
func handler(w http.ResponseWriter, r *http.Request) {
    result, err := slowQuery(r.Context())
    if err != nil {
        // If timeout already fired, this is a no-op
        chikit.SetError(r, chikit.ErrInternal)
        return
    }
    // If timeout already fired, this is a no-op
    chikit.SetResponse(r, http.StatusOK, result)
}
```

### Panic Recovery

Handler automatically catches panics and returns `ErrInternal`:

```go
r.Use(chikit.Handler())
r.Get("/panic", func(w http.ResponseWriter, r *http.Request) {
    panic("oops")  // Returns 500 {"error": {"type": "internal_error", ...}}
})
```

### Thread Safety

State operations use mutex protection - safe for concurrent middleware access.

---

## Timeout Patterns

### Handling context.DeadlineExceeded

When timeout fires, the context is cancelled. DB/HTTP calls return `context.DeadlineExceeded`:

```go
func handler(w http.ResponseWriter, r *http.Request) {
    result, err := db.Query(r.Context())
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return // Timeout already handled by middleware
        }
        chikit.SetError(r, chikit.ErrInternal.With("Query failed"))
        return
    }
    chikit.SetResponse(r, http.StatusOK, result)
}
```

### Application Error Handler Pattern

```go
func HandleError(r *http.Request, err error) {
    if errors.Is(err, context.DeadlineExceeded) {
        return // Timeout already handled by middleware
    }
    chikit.SetError(r, ToAPIError(err))
}
```

---

## Dual-Mode Middleware Pattern

Middleware should check `chikit.HasState()` to support standalone use:

```go
func MyMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if err := validate(r); err != nil {
            if chikit.HasState(r.Context()) {
                chikit.SetError(r, chikit.ErrBadRequest.With(err.Error()))
            } else {
                http.Error(w, err.Error(), http.StatusBadRequest)
            }
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

All chikit middleware uses this pattern internally.

---

## Layered Rate Limiting with RateLimitWithName()

When applying multiple rate limiters, **use `RateLimitWithName()` to prevent key collisions**:

```go
// Without RateLimitWithName() - COLLISION!
// Both limiters use same key: "192.168.1.1"
r.Use(chikit.NewRateLimiter(st, 1000, time.Hour, chikit.RateLimitWithIP()).Handler)
r.Use(chikit.NewRateLimiter(st, 100, time.Minute, chikit.RateLimitWithIP()).Handler)

// With RateLimitWithName() - independent keys
// Keys: "global:192.168.1.1" and "api:192.168.1.1"
globalLimiter := chikit.NewRateLimiter(st, 1000, time.Hour,
    chikit.RateLimitWithName("global"),
    chikit.RateLimitWithIP(),
)
apiLimiter := chikit.NewRateLimiter(st, 100, time.Minute,
    chikit.RateLimitWithName("api"),
    chikit.RateLimitWithIP(),
)
```

### Three-Tier Pattern

```go
// Tier 1: DDoS protection (broad)
ddosLimiter := chikit.NewRateLimiter(st, 10000, time.Hour,
    chikit.RateLimitWithName("ddos"),
    chikit.RateLimitWithIP(),
)
r.Use(ddosLimiter.Handler)

// Tier 2: Per-tenant fairness
tenantLimiter := chikit.NewRateLimiter(st, 1000, time.Minute,
    chikit.RateLimitWithName("tenant"),
    chikit.RateLimitWithHeaderRequired("X-Tenant-ID"),
)
r.Use(tenantLimiter.Handler)

// Tier 3: Expensive endpoint protection
r.Route("/api/reports", func(r chi.Router) {
    reportLimiter := chikit.NewRateLimiter(st, 10, time.Hour,
        chikit.RateLimitWithName("reports"),
        chikit.RateLimitWithHeaderRequired("X-Tenant-ID"),
    )
    r.Use(reportLimiter.Handler)
})
```

---

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Not returning after SetError | Handler continues executing | Always `return` after SetError |
| Writing to ResponseWriter directly | Bypasses Handler, inconsistent format | Use SetError/SetResponse |
| Handler not outermost middleware | State not in context | Move `chikit.Handler()` to first position |
| Memory store in K8s | Limits not shared across pods | Use Redis store |
| Missing RateLimitWithName() on layered limiters | Key collisions | Add unique `RateLimitWithName("...")` |
| Forgetting `defer st.Close()` | Connection leaks | Always defer Close() |
| High cardinality keys | Redis memory explosion | Bound dimensions, avoid user×endpoint |
| Not handling context.DeadlineExceeded | Unnecessary error logging | Check for deadline exceeded in error handlers |

---

## Required vs Optional Dimensions

```go
// Optional: skip rate limiting if header missing
chikit.RateLimitWithHeader("X-Tenant-ID")

// Required: return 400 if header missing
chikit.RateLimitWithHeaderRequired("X-Tenant-ID")
```

**Use required when:**
- Tenant isolation is mandatory
- You need to enforce the dimension exists

**Use optional when:**
- Best-effort tracking is acceptable
- Missing value shouldn't block the request

---

## Testing Patterns

### Unit Tests with Memory Store

```go
func TestRateLimiting(t *testing.T) {
    st := store.NewMemory()
    t.Cleanup(func() { st.Close() })

    limiter := chikit.NewRateLimiter(st, 3, time.Minute, chikit.RateLimitWithIP())
    handler := limiter.Handler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))

    // First 3 requests succeed
    for i := 0; i < 3; i++ {
        req := httptest.NewRequest("GET", "/", nil)
        req.RemoteAddr = "1.1.1.1:1234"
        rec := httptest.NewRecorder()
        handler.ServeHTTP(rec, req)
        assert.Equal(t, http.StatusOK, rec.Code)
    }

    // 4th request exceeds limit
    req := httptest.NewRequest("GET", "/", nil)
    req.RemoteAddr = "1.1.1.1:1234"
    rec := httptest.NewRecorder()
    handler.ServeHTTP(rec, req)
    assert.Equal(t, http.StatusTooManyRequests, rec.Code)
}
```

### Integration Tests with Redis

```go
func TestRedisStore(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    st, err := store.NewRedis(store.RedisConfig{
        URL:    "localhost:6379",
        Prefix: "test:",
    })
    require.NoError(t, err)
    t.Cleanup(func() { st.Close() })

    // Test operations...
}
```

---

## MaxBodySize + chikit.JSON Integration

Two-stage body size protection:

1. **Content-Length check** (MaxBodySize middleware): Immediate 413 if header exceeds limit
2. **MaxBytesReader** (streaming): Catches chunked transfers and incorrect Content-Length

When using `chikit.JSON()`, the second stage is automatic:

```go
r.Use(chikit.Handler())
r.Use(chikit.MaxBodySize(1024 * 1024))  // 1MB limit
r.Use(chikit.Binder())

r.Post("/users", func(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    if !chikit.JSON(r, &req) {
        return  // Returns 413 if body exceeds limit, 400 if validation fails
    }
})
```

---

## SLO Integration Pattern

**Requirements:**
1. `chikit.WithCanonlog()` - enables request logging
2. `chikit.WithSLOs()` - enables SLO status tracking
3. `chikit.SLO(tier)` - per-route SLO assignment

```go
r.Use(chikit.Handler(
    chikit.WithCanonlog(),
    chikit.WithSLOs(),
))

r.With(chikit.SLO(chikit.SLOCritical)).Get("/health", healthHandler)
r.With(chikit.SLO(chikit.SLOHighFast)).Get("/users/{id}", getUser)
r.With(chikit.SLO(chikit.SLOLow)).Post("/batch", batchProcess)
```

**Log output:**
```json
{"method":"GET","path":"/users/123","status":200,"duration_ms":45,"slo_class":"high_fast","slo_status":"PASS"}
{"method":"GET","path":"/users/456","status":200,"duration_ms":150,"slo_class":"high_fast","slo_status":"FAIL"}
```

---

## Complete Example: Multi-Tenant API

A production-ready setup with Redis, layered rate limiting, authentication, timeout, and SLO tracking.

```go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/nhalm/canonlog"
    "github.com/nhalm/chikit"
    "github.com/nhalm/chikit/store"
)

type CreateUserRequest struct {
    Email string `json:"email" validate:"required,email"`
    Name  string `json:"name" validate:"required,min=2,max=100"`
}

func main() {
    // Setup logging
    canonlog.SetupGlobalLogger("info", "json")

    // Redis store for production
    st, err := store.NewRedis(store.RedisConfig{
        URL:    "redis:6379",
        Prefix: "api:",
    })
    if err != nil {
        log.Fatal(err)
    }
    defer st.Close()

    r := chi.NewRouter()

    // 1. Handler MUST be outermost (with timeout and logging)
    r.Use(chikit.Handler(
        chikit.WithTimeout(30*time.Second),
        chikit.WithCanonlog(),
        chikit.WithSLOs(),
    ))

    // 2. Real IP before rate limiting
    r.Use(middleware.RealIP)

    // 3. Global rate limit: 1000 req/hour by IP (DDoS protection)
    globalLimiter := chikit.NewRateLimiter(st, 1000, time.Hour,
        chikit.RateLimitWithName("global"),
        chikit.RateLimitWithIP(),
    )
    r.Use(globalLimiter.Handler)

    // 4. Body size limit (1MB)
    r.Use(chikit.MaxBodySize(1024 * 1024))

    // 5. Bind configuration
    r.Use(chikit.Binder())

    // 6. Extract tenant ID (required)
    r.Use(chikit.ExtractHeader("X-Tenant-ID", "tenant_id", chikit.ExtractRequired()))

    // 7. API key authentication
    r.Use(chikit.APIKey(validateAPIKey))

    // 8. Per-tenant rate limit: 100 req/min
    tenantLimiter := chikit.NewRateLimiter(st, 100, time.Minute,
        chikit.RateLimitWithName("tenant"),
        chikit.RateLimitWithHeaderRequired("X-Tenant-ID"),
    )
    r.Use(tenantLimiter.Handler)

    // Routes with SLO tracking
    r.With(chikit.SLO(chikit.SLOCritical)).Get("/health", healthHandler)
    r.With(chikit.SLO(chikit.SLOHighFast)).Post("/users", createUserHandler)
    r.With(chikit.SLO(chikit.SLOHighFast)).Get("/users/{id}", getUserHandler)

    srv := &http.Server{Addr: ":8080", Handler: r}
    go func() {
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    // Wait for shutdown signal
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
    <-sigCh

    // Graceful shutdown
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    srv.Shutdown(ctx)
    chikit.WaitForHandlers(ctx)  // Wait for handler goroutines
}

func validateAPIKey(key string) bool {
    // In production: validate against database or cache
    return len(key) > 0
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    chikit.SetResponse(r, http.StatusOK, map[string]string{"status": "ok"})
}

func createUserHandler(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    if !chikit.JSON(r, &req) {
        return // Error already set (400 validation or 413 body too large)
    }

    // Get tenant from context
    tenantID, _ := chikit.HeaderFromContext(r.Context(), "tenant_id")

    // Create user...
    user := map[string]any{
        "id":        "usr_123",
        "email":     req.Email,
        "name":      req.Name,
        "tenant_id": tenantID,
    }

    chikit.SetResponse(r, http.StatusCreated, user)
}

func getUserHandler(w http.ResponseWriter, r *http.Request) {
    userID := chi.URLParam(r, "id")
    if userID == "" {
        chikit.SetError(r, chikit.ErrBadRequest.WithParam("User ID required", "id"))
        return
    }

    // Fetch user...
    user := map[string]any{"id": userID, "name": "Example User"}
    chikit.SetResponse(r, http.StatusOK, user)
}
```

This example demonstrates:
- Correct middleware ordering
- Request timeout with graceful shutdown
- Layered rate limiting with `RateLimitWithName()` (global + per-tenant)
- Required header extraction
- API key authentication
- JSON binding with validation
- SLO tracking per route
- Structured error responses
