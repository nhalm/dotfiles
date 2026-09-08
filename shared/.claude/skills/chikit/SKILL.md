---
name: chikit
description: Production-grade Chi middleware library for distributed Go systems. Use when implementing rate limiting, request validation, authentication, SLO tracking, error sanitization, header extraction, or request timeouts. Activates for Chi router middleware, Redis-backed distributed systems, and multi-instance Kubernetes deployments.
---

# chikit - Chi Middleware Library

Production-grade middleware for Chi routers in distributed Go systems. Part of the *kit ecosystem.

## Installation

```bash
go get github.com/nhalm/chikit
```

## Core Principles

- **Context-based responses**: Handlers use `chikit.SetError/SetResponse`, never write to ResponseWriter directly
- **Explicit initialization**: Accept structs/parameters, never read env vars or config files
- **Dual-mode support**: Middleware checks `chikit.HasState()` to work standalone or with Handler
- **Distributed-first**: Redis for production, in-memory only for dev/testing

## API Overview

| Function | Purpose |
|----------|---------|
| `Handler()` | Response handling, structured errors, timeout, panic recovery |
| `NewRateLimiter()` | Multi-dimensional rate limiting |
| `Binder()` | JSON/query binding + validation |
| `ValidateHeaders()` | Header validation with allow/deny lists |
| `MaxBodySize()` | Body size limits |
| `ExtractHeader()` | Header extraction to context |
| `APIKey()` | API key authentication |
| `BearerToken()` | Bearer token authentication |
| `SLO()` | SLO tracking with tiers |

## Quick Start

```go
import (
    "github.com/go-chi/chi/v5"
    "github.com/nhalm/chikit"
    "github.com/nhalm/chikit/store"
)

func main() {
    r := chi.NewRouter()

    // Handler MUST be outermost - handles all response writing
    r.Use(chikit.Handler(
        chikit.WithTimeout(30*time.Second),
        chikit.WithCanonlog(),
    ))

    // Rate limiting
    st := store.NewMemory()
    defer st.Close()
    r.Use(chikit.NewRateLimiter(st, 100, time.Minute, chikit.RateLimitWithIP()).Handler)

    r.Post("/users", func(w http.ResponseWriter, r *http.Request) {
        user, err := createUser(r)
        if err != nil {
            chikit.SetError(r, chikit.ErrInternal.With("Failed to create user"))
            return
        }
        chikit.SetResponse(r, http.StatusCreated, user)
    })
}
```

## Middleware Ordering

```go
r := chi.NewRouter()
r.Use(chikit.Handler())                          // 1. MUST be outermost
r.Use(middleware.RealIP)                         // 2. Real IP (before rate limiting)
r.Use(chikit.NewRateLimiter(...).Handler)        // 3. Rate limiting
r.Use(chikit.MaxBodySize(1024*1024))             // 4. Body size limit (1MB)
r.Use(chikit.Binder())                           // 5. Binding configuration
r.Use(chikit.ExtractHeader(...))                 // 6. Header extraction
r.Use(chikit.APIKey(...))                        // 7. Authentication
```

## Request Timeout

Hard-cutoff timeout guarantees response time:

```go
r.Use(chikit.Handler(
    chikit.WithTimeout(30*time.Second),
    chikit.WithGracefulShutdown(10*time.Second),
    chikit.WithAbandonCallback(func(r *http.Request) {
        // Handler didn't exit within grace period
    }),
))

// Graceful shutdown
srv.Shutdown(ctx)
chikit.WaitForHandlers(ctx)  // Wait for handler goroutines
```

## Structured Error Handling

**Handler handles ALL response writing.** Handlers and middleware set responses via context, Handler writes them in deferred cleanup.

```json
{"error": {"type": "not_found", "code": "resource_not_found", "message": "User not found"}}
```

**15 Sentinel Errors** (all support `.With(msg)` and `.WithParam(msg, param)`):
- `ErrBadRequest` (400), `ErrUnauthorized` (401), `ErrPaymentRequired` (402), `ErrForbidden` (403)
- `ErrNotFound` (404), `ErrMethodNotAllowed` (405), `ErrConflict` (409), `ErrGone` (410)
- `ErrPayloadTooLarge` (413), `ErrUnprocessableEntity` (422), `ErrRateLimited` (429)
- `ErrInternal` (500), `ErrNotImplemented` (501), `ErrServiceUnavailable` (503), `ErrGatewayTimeout` (504)

**Multi-field validation errors:**
```go
chikit.SetError(r, chikit.NewValidationError([]chikit.FieldError{
    {Param: "email", Code: "required", Message: "Email is required"},
    {Param: "age", Code: "min", Message: "Age must be at least 18"},
}))
```

## External Reference

For complete examples and API details, fetch the README:
- `https://raw.githubusercontent.com/nhalm/chikit/main/README.md`

## Error Responses by Middleware

| Status | Source | Condition |
|--------|--------|-----------|
| 400 | NewRateLimiter, ExtractHeader, ValidateHeaders, Binder | Missing required value, validation failed |
| 401 | APIKey, BearerToken | Invalid/missing credentials |
| 413 | MaxBodySize, Binder | Body too large |
| 429 | NewRateLimiter | Rate limit exceeded |
| 500 | NewRateLimiter | Store failure |
| 504 | Handler | Request timeout exceeded |

## Documentation Files

- **architecture.md** - Decision guidance, capacity planning, distributed systems
- **api-reference.md** - Condensed API signatures for all functions
- **patterns.md** - Integration patterns, error handling deep dive, anti-patterns
