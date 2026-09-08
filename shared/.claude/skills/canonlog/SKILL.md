---
name: canonlog
description: Canonical logging library for Go. Triggers when implementing request-scoped logging, accumulating context across handlers, or single-line request logs. Do NOT trigger for general slog usage without canonlog context.
---

# canonlog - Canonical Logging

Structured logging that accumulates context throughout a unit of work and emits a single log line at the end. Built on Go's standard `log/slog` with zero external dependencies.

## Core Philosophy

1. **Accumulate, don't scatter** - Collect fields throughout lifecycle, log once at completion
2. **Context-based** - Logger travels via `context.Context`, accessible anywhere in the call stack
3. **Defer-based logging** - Use `defer` to ensure logging happens even on panic
4. **Single line per request** - Reduces log noise, improves parsing, keeps data together
5. **Level-gated accumulation** - Fields only accumulate if configured level allows
6. **Per-logger level control** - Override global level with options pattern

## Quick Start

```go
import (
    "context"

    "github.com/nhalm/canonlog"
)

func main() {
    // Configure global logger
    canonlog.SetupGlobalLogger("info", "json")

    // Context-based usage
    ctx := canonlog.NewContext(context.Background())
    defer canonlog.Flush(ctx)

    canonlog.InfoAdd(ctx, "user_id", "123")
    canonlog.InfoAdd(ctx, "action", "login")
}
```

## API Reference

### Global Configuration

```go
// Configure slog output (idempotent - only executes once)
// Levels: "debug", "info", "warn" (or "warning"), "error"
// Formats: "text" (key=value pairs), "json"
// Invalid values fall back to defaults (info, text)
canonlog.SetupGlobalLogger(level, format string)
```

### Options

```go
// Override global level for a specific logger
canonlog.WithLevel(slog.Level) Option
```

### Logger Creation

```go
// Create logger with global level
l := canonlog.New()

// Create logger with custom level
l := canonlog.New(canonlog.WithLevel(slog.LevelError))
```

### Logger Methods (Chainable)

```go
l := canonlog.New()

// Level-gated field addition - only accumulates if level is enabled
l.DebugAdd(key string, value any) *Logger
l.DebugAddMany(map[string]any) *Logger
l.InfoAdd(key string, value any) *Logger
l.InfoAddMany(map[string]any) *Logger
l.WarnAdd(key string, value any) *Logger    // Escalates output level to Warn
l.WarnAddMany(map[string]any) *Logger       // Escalates output level to Warn
l.ErrorAdd(err error) *Logger               // Appends to errors array, escalates to Error

l.Flush(ctx context.Context)    // Emit log line and reset for reuse
```

### Context Helpers

```go
// Attach logger to context (replaces any existing logger)
ctx := canonlog.NewContext(ctx)

// Retrieve logger (panics if not found)
l := canonlog.GetLogger(ctx)

// Retrieve logger (safe, returns nil if not found)
l, ok := canonlog.TryGetLogger(ctx)

// Add fields at different levels (all panic if no logger in context)
canonlog.DebugAdd(ctx, "cache_key", key)
canonlog.DebugAddMany(ctx, map[string]any{"hit": true})

canonlog.InfoAdd(ctx, "user_id", userID)
canonlog.InfoAddMany(ctx, map[string]any{
    "org_id": orgID,
    "action": "create",
})

canonlog.WarnAdd(ctx, "retry_count", 3)
canonlog.WarnAddMany(ctx, map[string]any{"degraded": true})

canonlog.ErrorAdd(ctx, err)  // Takes error, appends err.Error() to errors array

// Emit log
canonlog.Flush(ctx)
```

## Log Level Behavior

```go
canonlog.SetupGlobalLogger("info", "json")  // Only info and above

canonlog.DebugAdd(ctx, "debug_field", "value")  // Ignored - level too low
canonlog.InfoAdd(ctx, "info_field", "value")    // Accumulated
canonlog.WarnAdd(ctx, "warn_field", "value")    // Accumulated, escalates to Warn
canonlog.ErrorAdd(ctx, err)                     // Appends to errors array, escalates to Error
```

The final log emits at the **highest accumulated level**. If any `ErrorAdd` is called, the log emits at ERROR level.

### Per-Logger Level Override

```go
// Create error-only logger regardless of global setting
l := canonlog.New(canonlog.WithLevel(slog.LevelError))

l.InfoAdd("ignored", "value")  // Not accumulated - below gate level
l.ErrorAdd(err)                // Accumulated
```

## Error Handling

`ErrorAdd` takes an `error` and appends `err.Error()` to an internal slice. All errors appear as an `errors` array in the output. Maximum 10 errors are stored; if exceeded, `"...and N more"` is appended.

```go
canonlog.ErrorAdd(ctx, errors.New("first error"))
canonlog.ErrorAdd(ctx, errors.New("second error"))
// Output includes: "errors": ["first error", "second error"]

// Nil errors are silently ignored
canonlog.ErrorAdd(ctx, nil)  // No-op, level not escalated
```

## Flush Behavior

Flush emits the log line and **resets the logger for reuse**:
- Clears all fields
- Clears errors slice
- Resets output level to gate level
- Safe for concurrent/duplicate calls (no-op if nothing to log)
- Context is passed to slog handler for trace propagation

This enables batch processing patterns:

```go
func processBatches(ctx context.Context, batches []Batch) error {
    ctx = canonlog.NewContext(ctx)

    for _, batch := range batches {
        canonlog.InfoAdd(ctx, "batch_id", batch.ID)
        canonlog.InfoAdd(ctx, "size", len(batch.Items))

        if err := processBatch(ctx, batch); err != nil {
            canonlog.ErrorAdd(ctx, err)
        }

        canonlog.Flush(ctx)  // Emit and reset for next batch
    }
    return nil
}
```

## Example Output

### Text Format

```
time=2025-01-15T10:30:45Z level=INFO msg="" user_id=123 action=fetch_profile cache_hit=true
```

### JSON Format

```json
{
  "time": "2025-01-15T10:30:45Z",
  "level": "INFO",
  "msg": "",
  "user_id": "123",
  "action": "fetch_profile",
  "cache_hit": true
}
```

### With Errors

```json
{
  "time": "2025-01-15T10:30:45Z",
  "level": "ERROR",
  "msg": "",
  "user_id": "123",
  "errors": ["connection timeout", "retry failed"]
}
```

## Multi-Layer Architecture

Canonlog works across layered architectures by passing context through every layer.

### API Layer

```go
func (h *Handler) CreateProduct(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    canonlog.InfoAddMany(ctx, map[string]any{
        "product_name": req.Name,
        "category":     req.Category,
    })

    product, err := h.productSvc.CreateProduct(ctx, &serviceReq)
    if err != nil {
        canonlog.ErrorAdd(ctx, err)
        renderError(w, r, err)
        return
    }

    canonlog.InfoAdd(ctx, "product_id", product.ID)
    render(w, r, http.StatusCreated, toProductResponse(product))
}
```

### Service Layer

```go
func (s *ProductService) CreateProduct(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    canonlog.InfoAdd(ctx, "operation", "create_product")

    if err := s.validate(req); err != nil {
        canonlog.WarnAddMany(ctx, map[string]any{
            "validation_failed": true,
            "validation_error":  err.Error(),
        })
        return nil, apperrors.NewValidationError(err.Error())
    }

    product, err := s.repo.Create(ctx, req)
    if err != nil {
        canonlog.ErrorAdd(ctx, err)
        return nil, err
    }

    canonlog.InfoAdd(ctx, "product_created", true)
    return product, nil
}
```

### Repository Layer

```go
func (r *ProductRepository) Create(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
    canonlog.InfoAdd(ctx, "db_operation", "insert_product")

    product, err := r.db.Insert(ctx, req)
    if err != nil {
        canonlog.ErrorAdd(ctx, err)
        return nil, err
    }

    canonlog.InfoAdd(ctx, "rows_affected", 1)
    return product, nil
}
```

## Background Jobs

```go
func processJob(jobID string) error {
    ctx := canonlog.NewContext(context.Background())
    defer canonlog.Flush(ctx)

    canonlog.InfoAdd(ctx, "job_id", jobID)
    canonlog.InfoAdd(ctx, "worker", "background-processor")

    if err := doWork(); err != nil {
        canonlog.ErrorAdd(ctx, err)
        return err
    }
    return nil
}
```

Or using Logger directly:

```go
func processJobDirect(jobID string) error {
    ctx := context.Background()
    l := canonlog.New()
    defer l.Flush(ctx)

    l.InfoAdd("job_id", jobID).
        InfoAdd("worker", "background-processor")

    if err := doWork(); err != nil {
        l.ErrorAdd(err)
        return err
    }
    return nil
}
```

## Chaining with GetLogger

```go
func handleRequest(ctx context.Context, req *Request) {
    // Individual calls
    canonlog.InfoAdd(ctx, "user_id", req.UserID)
    canonlog.InfoAdd(ctx, "action", req.Action)

    // Or chain with GetLogger
    canonlog.GetLogger(ctx).
        InfoAdd("ip", req.RemoteAddr).
        InfoAdd("user_agent", req.UserAgent).
        InfoAddMany(map[string]any{
            "method": req.Method,
            "path":   req.Path,
        })
}
```

## Thread Safety

Logger is fully thread-safe. Multiple goroutines can add fields to the same logger, and Flush is safe to call concurrently or multiple times:

```go
func processWork(ctx context.Context) {
    var wg sync.WaitGroup
    wg.Add(2)

    go func() {
        defer wg.Done()
        canonlog.InfoAdd(ctx, "task1", "done")  // Safe
    }()

    go func() {
        defer wg.Done()
        canonlog.InfoAdd(ctx, "task2", "done")  // Safe
    }()

    wg.Wait()
}
```

## Anti-Patterns

**Don't:**
- Emit multiple log lines per request (defeats the purpose)
- Forget `defer` for Flush (miss logs on panic/early return)
- Ignore context parameter (fields won't accumulate)
- Log sensitive data (PII, credentials, tokens)
- Call `ErrorAdd` with a key/value - it only takes `error`

**Do:**
- Use `defer canonlog.Flush(ctx)` at entry points
- Add context progressively as you learn more about the request
- Use `ErrorAdd(err)` for errors (appends to errors array, escalates level)
- Use `TryGetLogger` when logger might not exist in context
