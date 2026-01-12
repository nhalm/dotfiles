# Architecture & Decision Guide

## Handler as Foundation

The `Handler()` middleware is the architectural foundation. It **must be the outermost middleware**.

**Why:**
1. Creates `State` in context at request start
2. All middleware uses `SetError`/`SetResponse` instead of writing to ResponseWriter
3. Single response point: writes JSON in deferred cleanup after handler completes
4. Provides panic recovery, consistent error format, timeout handling, and response headers

**State Lifecycle:**
```
Request arrives → Handler() creates State in context
                → Handler/middleware call SetError or SetResponse
                → Handler writes response in defer (single write point)
```

---

## Request Timeout Architecture

### How It Works

```
Handler(WithTimeout(30s))
    │
    ├─ Create context.WithTimeout()
    ├─ Run handler in goroutine
    │
    ├─ Handler completes first?
    │   └─ Normal response path
    │
    └─ Timeout fires first?
        ├─ Write 504 immediately
        ├─ Context cancelled (DB/HTTP calls exit early)
        ├─ Wait grace period for handler to exit
        └─ If handler doesn't exit → abandon callback
```

### Graceful Shutdown Pattern

```go
srv := &http.Server{Addr: ":8080", Handler: r}
go srv.ListenAndServe()

<-shutdownSignal

ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

srv.Shutdown(ctx)           // Wait for in-flight requests
chikit.WaitForHandlers(ctx) // Wait for handler goroutines
```

### Timeout Considerations

| Scenario | Behavior |
|----------|----------|
| Handler completes before timeout | Normal response |
| Timeout fires, handler exits within grace | 504 response, clean exit |
| Timeout fires, handler doesn't exit | 504 response, abandon callback, goroutine continues |
| Handler panics before timeout | 500 response |
| Handler panics after timeout | 504 response (timeout wins), panic logged |

**Important:** Go cannot forcibly terminate goroutines. If handlers ignore context cancellation (CGO calls, tight CPU loops), they continue running after the 504 response.

---

## Rate Limiting Strategy

### Decision Tree

```
Is this a public endpoint without auth?
  → RateLimitWithIP() for DDoS protection

Do you have tenant/customer identification?
  → RateLimitWithHeaderRequired("X-Tenant-ID") for per-customer fairness

Is this a developer API with API keys?
  → RateLimitWithHeaderRequired("X-API-Key") for per-key limits

Need to protect specific expensive endpoints?
  → Add RateLimitWithEndpoint() to create per-endpoint limits

Need multiple dimensions (IP + tenant + endpoint)?
  → Combine options, use RateLimitWithName() to prevent key collisions
```

### Strategy Comparison

| Strategy | Use Case | Pros | Cons |
|----------|----------|------|------|
| `RateLimitWithIP()` | DDoS, anonymous APIs | Always available, broad coverage | NAT/proxy issues, IPv6 |
| `RateLimitWithRealIP()` | Behind load balancer | Actual client IP | Requires trusted proxy |
| `RateLimitWithHeaderRequired()` | Multi-tenant SaaS | Maps to business model | Requires auth first |
| `RateLimitWithEndpoint()` | Expensive operations | Target bottlenecks | Doesn't prevent per-user abuse |
| `RateLimitWithQueryParam()` | Per-resource limits | Fine-grained | High cardinality risk |
| Multi-dimensional | Complex SaaS | Precise isolation | Cardinality explosion risk |

### Required vs Optional Dimensions

- `RateLimitWithHeader("X-Tenant-ID")` - **Skip** rate limiting if header missing
- `RateLimitWithHeaderRequired("X-Tenant-ID")` - Return **400** if header missing

Use **required** for mandatory tenant isolation. Use **optional** for best-effort tracking where missing values shouldn't block requests.

---

## Storage Backend Selection

| Scenario | Backend | Notes |
|----------|---------|-------|
| Development/testing | `store.NewMemory()` | Per-instance state |
| Single instance production | Either | Redis preferred for consistency |
| Multi-instance (K8s, ECS) | **Redis required** | Memory store = limit × instance_count |

```go
// Development
st := store.NewMemory()
defer st.Close()

// Production
st, err := store.NewRedis(store.RedisConfig{
    URL:    "redis:6379",
    Prefix: "rl:",
})
```

---

## Capacity Planning

### Redis Memory Formula

```
Required Memory = (Unique Keys × 200 bytes × 2) + 100MB overhead
```

### Cardinality by Dimension

| Dimension | Typical Cardinality |
|-----------|---------------------|
| IP addresses | 100k - 1M active |
| Tenant IDs | 100 - 100k |
| Endpoints | 10 - 500 |
| API keys | 100 - 100k |
| User IDs | 10k - 10M |

### Multi-Dimensional Cardinality

**Safe combinations:**
- `RateLimitWithIP()` alone → ~1M keys
- `RateLimitWithIP() + RateLimitWithHeaderRequired("X-Tenant-ID")` → IPs per tenant (contained)

**Dangerous combinations:**
- `RateLimitWithIP() + RateLimitWithEndpoint()` → IPs × Endpoints (multiplicative!)
- `RateLimitWithHeader("User-ID") + RateLimitWithEndpoint()` → Users × Endpoints (high risk!)

| Scenario | Keys | Memory |
|----------|------|--------|
| 100k IPs | 100k | 40MB |
| 10k tenants | 10k | 4MB |
| 10k tenants × 50 endpoints | 500k | 200MB |
| 1M users × 50 endpoints | 50M | **20GB** |

**Rule:** Keep total cardinality < 10M keys per Redis instance.

---

## Distributed Systems Considerations

### State Synchronization

Without shared state, effective limit = `limit × instance_count`:
- 3 K8s pods, 100 req/min per pod = 300 req/min effective

**Solution:** Always use Redis in multi-instance deployments.

### Failure Modes

When Redis is unavailable:
- **Current behavior:** Returns 500 (fail-closed), all requests blocked
- **Trade-off:** Fail-closed prevents abuse but causes outage

**Mitigation:**
- Redis with replicas + infrastructure-level failover
- Custom circuit breaker store wrapper (implement yourself)

### Rolling Deployments

If key format changes between versions, limits may not be enforced correctly during rollout. Use `RateLimitWithName("v2")` to version limiters if key structure changes.

### Clock Considerations

Redis uses server time for TTL - no clock sync issues between app instances. This is handled automatically.
