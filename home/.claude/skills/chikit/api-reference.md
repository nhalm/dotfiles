# API Reference

Condensed API signatures for chikit. For complete examples, fetch the README.

---

## Handler

The foundation middleware for context-based response handling.

### Middleware

```go
func Handler(opts ...HandlerOption) func(http.Handler) http.Handler
```

**Options:**
```go
WithCanonlog()                                        // Enable canonlog integration
WithCanonlogFields(fn func(*http.Request) map[string]any)  // Add custom log fields
WithSLOs()                                            // Enable SLO status logging (requires WithCanonlog)
WithTimeout(d time.Duration)                          // Hard-cutoff timeout (returns 504)
WithGracefulShutdown(d time.Duration)                 // Grace period after timeout (default 5s)
WithAbandonCallback(fn func(*http.Request))           // Called when handler doesn't exit in grace period
```

### Timeout Support

```go
func WaitForHandlers(ctx context.Context) error  // Wait for handler goroutines during shutdown
func ActiveHandlerCount() int                    // Number of running handler goroutines
```

### Response Functions

```go
func SetError(r *http.Request, err *APIError)           // Set error response
func SetResponse(r *http.Request, status int, body any) // Set success response
func SetHeader(r *http.Request, key, value string)      // Set response header (replaces)
func AddHeader(r *http.Request, key, value string)      // Add response header (appends)
func HasState(ctx context.Context) bool                 // Check if Handler is active
```

### APIError Type

```go
type APIError struct {
    Type    string       `json:"type"`              // Error category
    Code    string       `json:"code,omitempty"`    // Specific error code
    Message string       `json:"message"`           // Human-readable message
    Param   string       `json:"param,omitempty"`   // Field name (validation)
    Errors  []FieldError `json:"errors,omitempty"`  // Multiple field errors
    Status  int          `json:"-"`                 // HTTP status (not serialized)
}

type FieldError struct {
    Param   string `json:"param"`
    Code    string `json:"code"`
    Message string `json:"message"`
}
```

**Methods:**
```go
func (e *APIError) With(message string) *APIError              // Copy with custom message
func (e *APIError) WithParam(message, param string) *APIError  // Copy with message + field
func (e *APIError) Error() string                              // Implements error interface
func (e *APIError) Is(target error) bool                       // Implements errors.Is
```

### Sentinel Errors

| Variable | HTTP Status | Type | Code |
|----------|-------------|------|------|
| `ErrBadRequest` | 400 | request_error | bad_request |
| `ErrUnauthorized` | 401 | auth_error | unauthorized |
| `ErrPaymentRequired` | 402 | request_error | payment_required |
| `ErrForbidden` | 403 | auth_error | forbidden |
| `ErrNotFound` | 404 | not_found | resource_not_found |
| `ErrMethodNotAllowed` | 405 | request_error | method_not_allowed |
| `ErrConflict` | 409 | request_error | conflict |
| `ErrGone` | 410 | request_error | gone |
| `ErrPayloadTooLarge` | 413 | request_error | payload_too_large |
| `ErrUnprocessableEntity` | 422 | validation_error | unprocessable |
| `ErrRateLimited` | 429 | rate_limit_error | limit_exceeded |
| `ErrInternal` | 500 | internal_error | internal |
| `ErrNotImplemented` | 501 | request_error | not_implemented |
| `ErrServiceUnavailable` | 503 | request_error | service_unavailable |
| `ErrGatewayTimeout` | 504 | timeout_error | gateway_timeout |

### Validation Error Constructor

```go
func NewValidationError(errors []FieldError) *APIError  // Returns 400 with multiple field errors
```

---

## Rate Limiting

Multi-dimensional rate limiting with functional options.

### Constructor

```go
func NewRateLimiter(store Store, limit int, window time.Duration, opts ...RateLimitOption) *RateLimiter
```

**Note:** Panics if no key dimension options provided.

### RateLimiter

```go
func (l *RateLimiter) Handler(next http.Handler) http.Handler
```

### Key Dimension Options

```go
RateLimitWithIP()                         // RemoteAddr IP (direct connections)
RateLimitWithRealIP()                     // X-Forwarded-For/X-Real-IP (skip if missing)
RateLimitWithRealIPRequired()             // Same, but 400 if missing
RateLimitWithEndpoint()                   // HTTP method + path
RateLimitWithHeader(name string)          // Header value (skip if missing)
RateLimitWithHeaderRequired(name string)  // Header value (400 if missing)
RateLimitWithQueryParam(name string)      // Query param (skip if missing)
RateLimitWithQueryParamRequired(name string)  // Query param (400 if missing)
```

### Configuration Options

```go
RateLimitWithName(name string)            // Key prefix for layered rate limiting
RateLimitWithHeaderMode(mode RateLimitHeaderMode)  // Control response header behavior
```

### Header Modes

```go
RateLimitHeadersAlways           // Include on all responses (default)
RateLimitHeadersOnLimitExceeded  // Include only on 429
RateLimitHeadersNever            // Never include
```

### Response Headers

- `RateLimit-Limit` - Max requests in window
- `RateLimit-Remaining` - Requests left
- `RateLimit-Reset` - Unix timestamp when window resets
- `Retry-After` - Seconds until reset (429 only)

---

## store

Storage backends for rate limiting.

### Interface

```go
type Store interface {
    Increment(ctx context.Context, key string, window time.Duration) (count int64, ttl time.Duration, err error)
    Get(ctx context.Context, key string) (int64, error)
    Reset(ctx context.Context, key string) error
    Close() error
}
```

### Memory Store

```go
func NewMemory() *Memory  // In-memory, dev/testing only
```

### Redis Store

```go
func NewRedis(config RedisConfig) (*Redis, error)

type RedisConfig struct {
    URL          string        // Required: "host:port"
    Password     string        // Optional
    DB           int           // 0-15
    Prefix       string        // Key prefix (default: "ratelimit:")
    PoolSize     int           // Connection pool size
    MinIdleConns int
    DialTimeout  time.Duration
    ReadTimeout  time.Duration
    WriteTimeout time.Duration
}
```

---

## Binding

JSON body and query parameter binding with validation (uses go-playground/validator/v10).

### Middleware

```go
func Binder(opts ...BindOption) func(http.Handler) http.Handler

BindWithFormatter(fn func(field, tag, param string) string)  // Custom error messages
```

### Binding Functions

```go
func JSON(r *http.Request, dest any) bool   // Decode + validate JSON body
func Query(r *http.Request, dest any) bool  // Decode + validate query params
```

Returns `false` if validation fails (error already set in Handler).

### Custom Validators

```go
func RegisterValidation(tag string, fn validator.Func) error
```

### Struct Tags

```go
type Request struct {
    Email string `json:"email" validate:"required,email"`
    Age   int    `json:"age" validate:"omitempty,min=18"`
}

type Query struct {
    Page  int    `query:"page" validate:"omitempty,min=1"`
    Limit int    `query:"limit" validate:"omitempty,min=1,max=100"`
}
```

---

## Validation

Request validation middleware.

### Body Size

```go
func MaxBodySize(maxBytes int64, opts ...BodySizeOption) func(http.Handler) http.Handler
```

Two-stage protection:
1. Content-Length check (immediate 413)
2. MaxBytesReader wrapper (streaming protection)

### Header Validation

```go
func ValidateHeaders(opts ...ValidateHeadersOption) func(http.Handler) http.Handler

ValidateWithHeader(name string, opts ...ValidateOption) ValidateHeadersOption  // Add header rule
```

**Validate Options:**
```go
ValidateRequired()                  // 400 if missing
ValidateAllowList(values ...string) // Only these values allowed
ValidateDenyList(values ...string)  // These values blocked
ValidateCaseSensitive()             // Case-sensitive comparison (default: insensitive)
```

---

## Header Extraction

Header extraction to context.

```go
func ExtractHeader(header, ctxKey string, opts ...HeaderExtractorOption) func(http.Handler) http.Handler
func HeaderFromContext(ctx context.Context, key string) (any, bool)

// HeaderExtractorOption functions:
ExtractRequired() HeaderExtractorOption                                   // 400 if missing
ExtractDefault(val string) HeaderExtractorOption                          // Fallback value
ExtractWithValidator(fn func(string) (any, error)) HeaderExtractorOption  // Transform/validate
```

---

## Authentication

Authentication middleware.

### API Key

```go
func APIKey(validator func(key string) bool, opts ...APIKeyOption) func(http.Handler) http.Handler
func APIKeyFromContext(ctx context.Context) (string, bool)

WithAPIKeyHeader(name string)  // Custom header (default: X-API-Key)
WithOptionalAPIKey()           // Don't fail if missing
```

### Bearer Token

```go
func BearerToken(validator func(token string) bool, opts ...BearerTokenOption) func(http.Handler) http.Handler
func BearerTokenFromContext(ctx context.Context) (string, bool)

WithOptionalBearerToken()  // Don't fail if missing
```

---

## SLO Tracking

SLO tracking per route.

### Tiers

| Tier | Target | Use Case |
|------|--------|----------|
| `SLOCritical` | 50ms | Essential functions (99.99% availability) |
| `SLOHighFast` | 100ms | User-facing, quick responses |
| `SLOHighSlow` | 1000ms | Important, higher latency ok |
| `SLOLow` | 5000ms | Background tasks |

### Middleware

```go
func SLO(tier SLOTier) func(http.Handler) http.Handler           // Predefined tier
func SLOWithTarget(target time.Duration) func(http.Handler) http.Handler  // Custom target
func GetSLO(ctx context.Context) (SLOTier, time.Duration, bool)  // Retrieve from context
```

Requires `WithCanonlog()` and `WithSLOs()` on Handler to log PASS/FAIL status.
