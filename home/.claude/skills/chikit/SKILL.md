---
name: chikit
description: Production-grade Chi middleware library for distributed Go systems. Use when implementing rate limiting, request validation, authentication, SLO tracking, error sanitization, or header extraction. Activates for Chi router middleware, Redis-backed distributed systems, and multi-instance Kubernetes deployments.
---

# chikit - Chi Middleware Library

Production-grade middleware for Chi routers in distributed Go systems. Part of the *kit ecosystem.

## Core Principles

- **Explicit initialization**: Accept structs/parameters, never read env vars or config files
- **Distributed-first**: Redis for production, in-memory only for dev/testing
- **Two-tier API**: Simple functions for common cases, fluent builder for complex scenarios
- **Callback-based observability**: Integrate with any metrics/logging system

## Packages

| Package | Purpose |
|---------|---------|
| `ratelimit` | Rate limiting with multiple dimensions |
| `ratelimit/store` | Storage backends (Memory, Redis) |
| `sanitize` | Strip sensitive info from error responses |
| `headers` | Extract headers to context with validation |
| `slo` | SLO tracking via callbacks |
| `validate` | Query params, headers, body size validation |
| `auth` | API key and bearer token authentication |

---

## Rate Limiting

### Simple API

```go
import (
    "github.com/nhalm/chikit/ratelimit"
    "github.com/nhalm/chikit/ratelimit/store"
)

// By IP address
r.Use(ratelimit.ByIP(st, 100, time.Minute))

// By header value
r.Use(ratelimit.ByHeader(st, "X-API-Key", 1000, time.Hour))

// By HTTP method + path
r.Use(ratelimit.ByEndpoint(st, 50, time.Minute))

// By query parameter
r.Use(ratelimit.ByQueryParam(st, "client_id", 100, time.Minute))
```

### Builder API (Complex Scenarios)

```go
// Multi-dimensional: IP + tenant header
middleware := ratelimit.NewBuilder(st).
    WithIP().
    WithHeader("X-Tenant-ID").
    Limit(100, time.Minute)

// Named limiter (prevents key collisions when layering)
middleware := ratelimit.NewBuilder(st).
    WithName("api-gateway").
    WithIP().
    Limit(100, time.Minute)

// Custom key extraction
middleware := ratelimit.NewBuilder(st).
    WithCustomKey(func(r *http.Request) string {
        return extractUserID(r)
    }).
    Limit(50, time.Hour)

// Control header behavior
middleware := ratelimit.NewBuilder(st).
    WithIP().
    WithHeaderMode(ratelimit.HeadersOnLimitExceeded). // Only show on 429
    Limit(100, time.Minute)
```

### Header Mode Constants

```go
ratelimit.HeadersAlways          // All responses (default)
ratelimit.HeadersOnLimitExceeded // Only on 429
ratelimit.HeadersNever           // Never send headers
```

### Response Headers

| Header | Description |
|--------|-------------|
| `RateLimit-Limit` | Max requests in window |
| `RateLimit-Remaining` | Requests left |
| `RateLimit-Reset` | Unix timestamp when window resets |
| `Retry-After` | Seconds until reset (429 only) |

### Key Patterns

Keys are human-readable for Redis debugging:

| Function | Key Pattern |
|----------|-------------|
| `ByIP()` | `ip:192.168.1.1` |
| `ByHeader()` | `header:X-API-Key:abc123` |
| `ByEndpoint()` | `endpoint:GET:/api/users` |
| `ByQueryParam()` | `query:client_id:xyz` |
| Builder with name | `myname:192.168.1.1:tenant-abc` |

**Empty keys skip rate limiting** - useful for optional headers.

### Layered Rate Limiting

Use `WithName()` to prevent key collisions:

```go
// Tier 1: DDoS protection
r.Use(ratelimit.NewBuilder(st).
    WithName("ddos").
    WithIP().
    Limit(10000, time.Hour))

// Tier 2: API rate limit per tenant
r.Use(ratelimit.NewBuilder(st).
    WithName("api").
    WithHeader("X-Tenant-ID").
    WithEndpoint().
    Limit(100, time.Minute))
```

---

## Storage Backends

### Store Interface

```go
type Store interface {
    Increment(ctx context.Context, key string, window time.Duration) (count int64, ttl time.Duration, err error)
    Get(ctx context.Context, key string) (int64, error)
    Reset(ctx context.Context, key string) error
    Close() error
}
```

### Memory Store (Development Only)

```go
st := store.NewMemory()
defer st.Close()
```

**Warning**: Each instance maintains independent state. In multi-instance deployments, effective limit = limit × instance_count.

### Redis Store (Production)

```go
st, err := store.NewRedis(store.RedisConfig{
    URL:      "localhost:6379",
    Password: "",           // optional
    DB:       0,            // 0-15
    Prefix:   "ratelimit:", // key prefix
})
if err != nil {
    return fmt.Errorf("redis store: %w", err)
}
defer st.Close()
```

### Choosing a Backend

| Scenario | Backend |
|----------|---------|
| Single instance, development | Memory |
| Single instance, production | Either (Redis preferred) |
| Multiple instances (K8s, ECS) | **Redis required** |

### Redis Configuration Recommendations

```conf
maxmemory 256mb
maxmemory-policy volatile-ttl  # Evict expiring keys first
save ""                        # Disable RDB (ephemeral data)
appendonly no                  # Disable AOF
```

### Redis Topology

| Setup | Use Case |
|-------|----------|
| Single instance | Low-criticality, <10k req/s |
| Redis Sentinel | Production HA, automatic failover |
| Redis Cluster | Not recommended for rate limiting |

---

## Error Sanitization

Strip sensitive information from error responses:

```go
import "github.com/nhalm/chikit/sanitize"

// Default: strip stack traces and file paths
r.Use(sanitize.New())

// Custom configuration
r.Use(sanitize.New(
    sanitize.WithStackTraces(true),
    sanitize.WithFilePaths(true),
    sanitize.WithReplacementMessage("Internal Server Error"),
))
```

---

## Header Extraction

Extract headers to context for downstream handlers:

```go
import "github.com/nhalm/chikit/headers"

// Basic extraction
r.Use(headers.New("X-Request-ID", "requestID"))

// Required header (400 if missing)
r.Use(headers.New("X-Tenant-ID", "tenantID", headers.WithRequired()))

// With default value
r.Use(headers.New("X-Region", "region", headers.WithDefault("us-east-1")))

// With validation/transformation
r.Use(headers.New("X-User-ID", "userID",
    headers.WithRequired(),
    headers.WithValidator(func(v string) (any, error) {
        return uuid.Parse(v)
    }),
))

// Retrieve in handler
func handler(w http.ResponseWriter, r *http.Request) {
    tenantID, ok := headers.FromContext(r.Context(), "tenantID")
    if !ok {
        // header wasn't present
    }
}
```

---

## SLO Tracking

Callback-based metrics for any observability system:

```go
import "github.com/nhalm/chikit/slo"

r.Use(slo.Track(func(ctx context.Context, m slo.Metric) {
    // m.Method     - HTTP method (GET, POST, etc.)
    // m.Route      - Chi route pattern (/api/users/{id})
    // m.StatusCode - Response status code
    // m.Duration   - Request processing time

    // Prometheus example
    requestDuration.WithLabelValues(m.Method, m.Route).Observe(m.Duration.Seconds())
    requestCount.WithLabelValues(m.Method, m.Route, strconv.Itoa(m.StatusCode)).Inc()
}))
```

**Metric struct:**
```go
type Metric struct {
    Method     string
    Route      string
    StatusCode int
    Duration   time.Duration
}
```

---

## Request Validation

### Body Size Limits

```go
import "github.com/nhalm/chikit/validate"

// Limit to 1MB
r.Use(validate.MaxBodySize(1 << 20))

// Custom status and message
r.Use(validate.MaxBodySize(1<<20,
    validate.WithBodySizeStatus(http.StatusRequestEntityTooLarge),
    validate.WithBodySizeMessage("Request too large"),
))
```

### Query Parameter Validation

```go
r.Use(validate.QueryParams(
    validate.Param("page", validate.WithDefault("1")),
    validate.Param("limit",
        validate.WithRequired(),
        validate.WithValidator(validate.OneOf("10", "25", "50", "100")),
    ),
    validate.Param("sort",
        validate.WithValidator(validate.Pattern(`^[a-z_]+$`)),
    ),
))
```

**Built-in validators:**
- `validate.OneOf(values...)` - Must be one of specified values
- `validate.MinLength(n)` - Minimum string length
- `validate.MaxLength(n)` - Maximum string length
- `validate.Pattern(regex)` - Must match regex

### Header Validation

```go
r.Use(validate.Headers(
    validate.Header("Content-Type",
        validate.WithRequiredHeader(),
        validate.WithAllowList("application/json", "application/xml"),
    ),
    validate.Header("X-Deprecated-Header",
        validate.WithDenyList("bad-value"),
    ),
    validate.Header("X-Case-Sensitive",
        validate.WithCaseSensitive(),
    ),
))
```

---

## Authentication

### API Key

```go
import "github.com/nhalm/chikit/auth"

// Basic validation
r.Use(auth.APIKey(func(key string) bool {
    return key == expectedKey
}))

// Custom header (default: X-API-Key)
r.Use(auth.APIKey(validator, auth.WithAPIKeyHeader("Authorization")))

// Optional (doesn't fail if missing)
r.Use(auth.APIKey(validator, auth.WithOptionalAPIKey()))

// Retrieve in handler
func handler(w http.ResponseWriter, r *http.Request) {
    key, ok := auth.APIKeyFromContext(r.Context())
}
```

### Bearer Token

```go
// Validates Authorization: Bearer <token>
r.Use(auth.BearerToken(func(token string) bool {
    return validateJWT(token)
}))

// Optional token
r.Use(auth.BearerToken(validator, auth.WithOptionalBearerToken()))

// Retrieve in handler
token, ok := auth.BearerTokenFromContext(r.Context())
```

---

## Middleware Ordering

Order matters. Recommended sequence:

```go
r := chi.NewRouter()

// 1. Recovery (catch panics)
r.Use(middleware.Recoverer)

// 2. Real IP extraction (before rate limiting)
r.Use(middleware.RealIP)

// 3. SLO tracking (capture all requests)
r.Use(slo.Track(metricsCallback))

// 4. Global rate limiting
r.Use(ratelimit.ByIP(st, 1000, time.Minute))

// 5. Request validation
r.Use(validate.MaxBodySize(1 << 20))

// 6. Authentication
r.Use(auth.BearerToken(validator))

// 7. Error sanitization (before response)
r.Use(sanitize.New())

// Routes...
```

---

## Error Responses

| Status | Middleware | Condition |
|--------|------------|-----------|
| 400 | headers, validate, auth | Missing/invalid header or param |
| 401 | auth | Invalid/missing credentials |
| 403 | validate | Value in deny list |
| 413 | validate | Body too large |
| 429 | ratelimit | Rate limit exceeded |
| 500 | ratelimit | Store failure |

---

## Testing Patterns

```go
func TestRateLimiting(t *testing.T) {
    st := store.NewMemory()
    defer st.Close()

    handler := ratelimit.ByIP(st, 3, time.Minute)(
        http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            w.WriteHeader(http.StatusOK)
        }),
    )

    // Table-driven tests
    tests := []struct {
        name       string
        requests   int
        wantStatus int
    }{
        {"under limit", 3, http.StatusOK},
        {"at limit", 1, http.StatusTooManyRequests},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            for i := 0; i < tt.requests; i++ {
                req := httptest.NewRequest("GET", "/", nil)
                req.RemoteAddr = "192.168.1.1:1234"
                rec := httptest.NewRecorder()
                handler.ServeHTTP(rec, req)

                if i == tt.requests-1 {
                    if rec.Code != tt.wantStatus {
                        t.Errorf("got %d, want %d", rec.Code, tt.wantStatus)
                    }
                }
            }
        })
    }
}
```

---

## Distributed Systems Considerations

### State Synchronization

Without shared state, limit becomes `limit × instance_count`. Example:
- 3 K8s pods, 100 req/min limit per pod = 300 req/min effective

**Solution**: Always use Redis in multi-instance deployments.

### Failure Modes

When Redis is unavailable:
- Current behavior: Returns 500 (fail closed)
- All requests blocked until Redis recovers

**Mitigation options:**
1. Redis Sentinel for automatic failover
2. Health checks with circuit breaker (implement custom store wrapper)

### Clock Considerations

Redis uses server time for TTL - no clock sync issues between app instances.

### Rolling Deployments

If key format changes between versions, limits won't be enforced correctly during rollout. Use `WithName()` to version limiters if needed.

---

## Performance

| Operation | Latency |
|-----------|---------|
| Memory store | <100µs |
| Redis (same AZ) | 1-2ms |
| Redis (cross AZ) | 5-10ms |

**Capacity**: ~160 bytes per active key in Redis. 1M keys ≈ 160MB.

---

## Security Considerations

### Key Injection

Never use unsanitized user input in keys:

```go
// UNSAFE: User controls key content
ratelimit.ByHeader(st, "X-User-Supplied", 100, time.Minute)

// SAFE: Validate first
ratelimit.NewBuilder(st).
    WithCustomKey(func(r *http.Request) string {
        val := r.Header.Get("X-User-ID")
        if !isValidUUID(val) {
            return "" // Skip rate limiting
        }
        return val
    }).
    Limit(100, time.Minute)
```

### Memory Exhaustion

High-cardinality keys can exhaust Redis memory. Avoid:
- Request IDs (unique per request)
- Unbounded user input
- Search queries

Use bounded dimensions: IPs, tenant IDs, endpoints.

---

## Architectural Decision Guide

### Choosing a Rate Limiting Strategy

| Strategy | Use Case | Pros | Cons |
|----------|----------|------|------|
| `ByIP()` | DDoS protection, anonymous APIs | No auth required, broad coverage | Shared IPs (NAT, proxies), IPv6 issues |
| `ByHeader("X-Tenant-ID")` | Multi-tenant SaaS, per-customer limits | Maps to business model, fair allocation | Requires auth, header can be forged |
| `ByHeader("X-API-Key")` | Developer APIs, partner integrations | Per-key tracking, revocable | Key management overhead |
| `ByEndpoint()` | Protect expensive operations | Targets bottlenecks | Doesn't prevent per-user abuse |
| `ByQueryParam()` | Rate limit by resource ID | Fine-grained control | High cardinality risk |
| Builder (multi-dimensional) | Complex SaaS, fine-grained fairness | Precise isolation | Cardinality explosion risk |

### Decision Tree

```
Is this a public endpoint without auth?
  → ByIP() for DDoS protection

Do you have tenant/customer identification?
  → ByHeader("X-Tenant-ID") for per-customer fairness

Is this a developer API with API keys?
  → ByHeader("X-API-Key") for per-key limits

Need to protect specific expensive endpoints?
  → Add ByEndpoint() or layer with WithEndpoint()

Need multiple dimensions (IP + tenant + endpoint)?
  → Use Builder with WithName() to layer
```

### Layered Rate Limiting Architecture

```
Request Flow:
    │
    ▼
┌─────────────────────────────────────┐
│ Tier 1: DDoS Protection             │
│ ByIP(), 10k/hour                    │
│ Broad, fail-open acceptable         │
└─────────────────────────────────────┘
    │ passes
    ▼
┌─────────────────────────────────────┐
│ Tier 2: Per-Tenant Fairness         │
│ ByHeader("X-Tenant-ID"), 1k/min     │
│ Prevents noisy neighbor             │
└─────────────────────────────────────┘
    │ passes
    ▼
┌─────────────────────────────────────┐
│ Tier 3: Endpoint Protection         │
│ Builder with tenant+endpoint, 100/min│
│ Protects expensive operations       │
└─────────────────────────────────────┘
    │ passes
    ▼
  Handler
```

---

## Capacity Planning

### Redis Memory Sizing

**Formula:**
```
Required Memory = (Unique Keys × 200 bytes × 2) + 100MB overhead
```

**Cardinality by dimension:**

| Dimension | Typical Cardinality |
|-----------|---------------------|
| IP addresses | 100k - 1M active |
| Tenant IDs | 100 - 100k |
| User IDs | 10k - 10M |
| Endpoints | 10 - 500 |
| API keys | 100 - 100k |

**Multi-dimensional cardinality (Builder):**
- `WithIP().WithHeader("Tenant")` → IPs per tenant (contained, ~1M)
- `WithIP().WithEndpoint()` → IPs × Endpoints (multiplicative!)
- `WithHeader("User").WithEndpoint()` → Users × Endpoints (high risk!)

**Examples:**

| Scenario | Keys | Memory |
|----------|------|--------|
| 100k IPs | 100k | 40MB |
| 10k tenants | 10k | 4MB |
| 10k tenants × 50 endpoints | 500k | 200MB |
| 1M users × 50 endpoints | 50M | **20GB** ⚠️ |

**Rule**: Keep total cardinality < 10M keys for single Redis instance.

### Redis QPS Capacity

- Single Redis: ~100k ops/sec
- Rate limit check = 1 op (pipelined INCR + TTL)
- 10k req/s app traffic = 10% Redis capacity ✓
- 100k req/s = saturates Redis ⚠️

---

## Initialization & Lifecycle

### Application Startup

```go
func main() {
    // Initialize store (fail fast on startup)
    st, err := store.NewRedis(store.RedisConfig{
        URL:      "localhost:6379",
        Password: os.Getenv("REDIS_PASSWORD"),
        DB:       0,
        Prefix:   "ratelimit:",
    })
    if err != nil {
        log.Fatalf("redis store init: %v", err)
    }
    defer st.Close()

    // Build router
    r := chi.NewRouter()
    r.Use(ratelimit.ByIP(st, 100, time.Minute))
    // ... routes

    // Graceful shutdown
    srv := &http.Server{Addr: ":8080", Handler: r}

    go func() {
        sigChan := make(chan os.Signal, 1)
        signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
        <-sigChan

        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        defer cancel()
        srv.Shutdown(ctx)
    }()

    log.Fatal(srv.ListenAndServe())
}
```

### Health Checks

```go
func healthHandler(st store.Store) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx, cancel := context.WithTimeout(r.Context(), 1*time.Second)
        defer cancel()

        // Probe Redis connectivity
        if _, err := st.Get(ctx, "health:probe"); err != nil && err != redis.Nil {
            http.Error(w, "redis unavailable", http.StatusServiceUnavailable)
            return
        }
        w.WriteHeader(http.StatusOK)
    }
}
```

---

## Failure Modes & Resilience

### Redis Unavailable

**Current behavior**: Returns 500 (fail-closed), all requests blocked.

**Trade-offs:**
| Mode | Behavior | Risk |
|------|----------|------|
| Fail-closed (current) | Block all traffic | Service outage |
| Fail-open | Allow all traffic | Abuse/overload |

### Circuit Breaker Pattern

chikit doesn't include circuit breakers (by design). Implement via store wrapper:

```go
type CircuitBreakerStore struct {
    primary  store.Store
    fallback store.Store // memory store
    failures int64
    threshold int64
}

func (c *CircuitBreakerStore) Increment(ctx context.Context, key string, window time.Duration) (int64, time.Duration, error) {
    if atomic.LoadInt64(&c.failures) > c.threshold {
        // Circuit open - use fallback
        return c.fallback.Increment(ctx, key, window)
    }

    count, ttl, err := c.primary.Increment(ctx, key, window)
    if err != nil {
        atomic.AddInt64(&c.failures, 1)
        return c.fallback.Increment(ctx, key, window)
    }

    atomic.StoreInt64(&c.failures, 0)
    return count, ttl, nil
}
```

**Warning**: Fallback to memory = limits become per-instance during Redis outage.

### Redis Sentinel Failover

- Automatic failover takes 30-60 seconds
- During failover, rate limit checks fail (500 responses)
- Factor this into SLO calculations
- Use sentinel-aware Redis client configuration

---

## Observability

### Key Metrics to Track

```go
r.Use(slo.Track(func(ctx context.Context, m slo.Metric) {
    // Request metrics
    requestDuration.WithLabelValues(m.Method, m.Route).Observe(m.Duration.Seconds())
    requestCount.WithLabelValues(m.Method, m.Route, strconv.Itoa(m.StatusCode)).Inc()

    // Rate limit specific
    if m.StatusCode == 429 {
        rateLimitExceeded.WithLabelValues(m.Route).Inc()
    }
}))
```

**Recommended alerts:**
| Metric | Threshold | Meaning |
|--------|-----------|---------|
| 429 rate > 5% | High | Limits too aggressive or attack |
| 429 rate < 0.1% | Low | Limits may be too permissive |
| Redis latency p99 > 10ms | Warning | Redis performance issue |
| Redis errors > 0 | Critical | Rate limiting failing |

### Debugging Rate Limits

Redis keys are human-readable for debugging:

```bash
# See active rate limit keys
redis-cli KEYS "ratelimit:*"

# Check specific key
redis-cli GET "ratelimit:ip:192.168.1.1"
redis-cli TTL "ratelimit:ip:192.168.1.1"

# Monitor rate limit operations
redis-cli MONITOR | grep ratelimit
```

---

## Testing

### Unit Tests with Cleanup

```go
func TestRateLimiting(t *testing.T) {
    st := store.NewMemory()
    t.Cleanup(func() { st.Close() })

    handler := ratelimit.ByIP(st, 3, time.Minute)(
        http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            w.WriteHeader(http.StatusOK)
        }),
    )

    tests := []struct {
        name       string
        ip         string
        requests   int
        wantStatus int
    }{
        {"under limit", "1.1.1.1", 3, http.StatusOK},
        {"exceeds limit", "2.2.2.2", 4, http.StatusTooManyRequests},
        {"different IP resets", "3.3.3.3", 1, http.StatusOK},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            var lastStatus int
            for i := 0; i < tt.requests; i++ {
                req := httptest.NewRequest("GET", "/", nil)
                req.RemoteAddr = tt.ip + ":1234"
                rec := httptest.NewRecorder()
                handler.ServeHTTP(rec, req)
                lastStatus = rec.Code
            }
            if lastStatus != tt.wantStatus {
                t.Errorf("got %d, want %d", lastStatus, tt.wantStatus)
            }
        })
    }
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
    if err != nil {
        t.Fatalf("redis connection: %v", err)
    }
    t.Cleanup(func() { st.Close() })

    // Reset test key
    ctx := context.Background()
    st.Reset(ctx, "integration-test")

    count, _, err := st.Increment(ctx, "integration-test", time.Minute)
    if err != nil {
        t.Fatalf("increment: %v", err)
    }
    if count != 1 {
        t.Errorf("got count %d, want 1", count)
    }
}
```

---

## Notes

### MaxBodySize Behavior

`validate.MaxBodySize` wraps the request body with `http.MaxBytesReader` but does **not** automatically send error responses. Handlers must check for body read errors:

```go
r.Use(validate.MaxBodySize(1 << 20))

func handler(w http.ResponseWriter, r *http.Request) {
    body, err := io.ReadAll(r.Body)
    if err != nil {
        var maxBytesErr *http.MaxBytesError
        if errors.As(err, &maxBytesErr) {
            http.Error(w, "request too large", http.StatusRequestEntityTooLarge)
            return
        }
        http.Error(w, "read error", http.StatusBadRequest)
        return
    }
    // process body
}
```

### Context Retrieval with Type Assertion

When using `headers.FromContext` with validators that transform types:

```go
val, ok := headers.FromContext(r.Context(), "userID")
if !ok {
    // header missing
    return
}

// Safe type assertion
userID, ok := val.(uuid.UUID)
if !ok {
    // validator returned unexpected type
    return
}
```

---

## Anti-Patterns

**Don't:**
- Use memory store in multi-instance production
- Read env vars or config files in middleware
- Log keys containing sensitive data
- Use high-cardinality dimensions (user × endpoint)
- Skip `defer store.Close()`
- Forget graceful shutdown handling
- Use `X-Forwarded-For` without `middleware.RealIP` first

**Do:**
- Pass explicit config structs
- Use Redis for any >1 instance deployment
- Validate before using user input in keys
- Layer rate limiters with `WithName()`
- Test with memory store, deploy with Redis
- Implement health checks for Redis connectivity
- Monitor 429 rates and Redis latency
- Plan for Redis failure (circuit breaker or accept downtime)
