# Configuration Reference

Complete skimatik.yaml configuration options.

## Minimal Configuration

```yaml
database:
  dsn: "postgres://user:pass@localhost:5432/dbname"

output:
  directory: "./repositories"
  package: "repositories"

tables:
  users:
```

## Complete Configuration

```yaml
# Database connection (required)
database:
  dsn: "postgres://user:pass@localhost:5432/dbname?sslmode=disable"
  schema: "public"  # Default: "public"

# Output settings (required)
output:
  directory: "./repository/generated"
  package: "generated"

# Default CRUD functions for all tables
default_functions: "all"  # or array: ["create", "get", "update", "delete", "list", "paginate"]

# Tables to generate repositories for
tables:
  users:                              # Uses default_functions
  posts:
    functions: ["create", "get", "list"]  # Override per table
  comments:
    functions: []                     # No functions, struct only

# Custom queries from SQL files
queries:
  directory: "./database/queries"

# Custom type mappings
types:
  mappings:
    user_status: "UserStatus"
    payment_state: "PaymentState"

# Enable verbose logging
verbose: true
```

## Configuration Sections

### database

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `dsn` | string | Yes | - | PostgreSQL connection string |
| `schema` | string | No | `"public"` | Schema to introspect |

**DSN Format:**
```
postgres://[user[:password]@][host][:port][/dbname][?options]
```

**Examples:**
```yaml
database:
  dsn: "postgres://postgres:password@localhost:5432/mydb"
  dsn: "postgres://user@localhost/mydb?sslmode=require"
  dsn: "postgres://user:pass@db.example.com:5432/production?sslmode=verify-full"
```

### output

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `directory` | string | No | `"./repositories"` | Output directory for generated code |
| `package` | string | No | `"repositories"` | Go package name |

### default_functions

Controls which CRUD functions are generated for all tables by default.

**String format:**
```yaml
default_functions: "all"  # Expands to all functions
```

**Array format:**
```yaml
default_functions:
  - create
  - get
  - update
  - delete
  - list
  - paginate
```

**Available functions:**
| Function | Description |
|----------|-------------|
| `create` | Insert new records |
| `get` | Fetch by primary key |
| `update` | Update existing records |
| `delete` | Delete records |
| `list` | Fetch all records |
| `paginate` | Cursor-based pagination |

### tables

Map of table names to configuration. Tables inherit `default_functions` unless overridden.

```yaml
tables:
  users:                    # Uses default_functions
  posts:
    functions: ["create", "get", "list"]  # Custom set
  audit_logs:
    functions: ["create"]   # Create only
  lookup_data:
    functions: []           # No functions, struct only
```

### queries

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `directory` | string | No | - | Directory containing `.sql` query files |

Query files are parsed for `-- name:` annotations. Each file generates a `*Queries` struct.

```yaml
queries:
  directory: "./database/queries"
```

**File structure:**
```
database/
  queries/
    users.sql      → UsersQueries
    posts.sql      → PostsQueries
    reports.sql    → ReportsQueries
```

### types.mappings

Custom PostgreSQL to Go type mappings:

```yaml
types:
  mappings:
    user_status: "UserStatus"      # Enum type
    payment_state: "PaymentState"  # Enum type
    money_amount: "decimal.Decimal" # Custom type
```

You must define these types in your Go code:

```go
type UserStatus string

const (
    UserStatusActive   UserStatus = "active"
    UserStatusInactive UserStatus = "inactive"
)
```

### verbose

```yaml
verbose: true  # Default: false
```

Enables detailed logging:
- Database connection info
- Tables discovered
- Queries parsed
- Files generated

## CLI Flags

```bash
skimatik [options]
```

| Flag | Description |
|------|-------------|
| `--config` | Path to config file (default: `skimatik.yaml`) |
| `--verbose` | Enable verbose logging (overrides config) |
| `--version` | Show version |
| `--help` | Show help |

**Examples:**
```bash
skimatik                                    # Use skimatik.yaml
skimatik --config=custom.yaml               # Custom config
skimatik --config=skimatik.yaml --verbose   # Verbose output
```

## Environment Variables

Set the DSN via command line or shell:
```bash
# Pass DSN directly in config or use shell substitution
skimatik --config=<(cat <<EOF
database:
  dsn: "$DATABASE_URL"
output:
  directory: "./repository/generated"
  package: "generated"
tables:
  users:
EOF
)
```

Note: YAML files do not automatically expand environment variables like `${DATABASE_URL}`. Use shell substitution or set the DSN directly in the config file.

## Example Configurations

### Simple Blog

```yaml
database:
  dsn: "postgres://postgres:password@localhost:5432/blog"

output:
  directory: "./repository/generated"
  package: "generated"

default_functions: "all"

tables:
  users:
  posts:
  comments:

queries:
  directory: "./database/queries"
```

### Microservice with Limited Functions

```yaml
database:
  dsn: "postgres://app:secret@localhost:5432/orders"
  schema: "orders"

output:
  directory: "./internal/db/repos"
  package: "repos"

tables:
  orders:
    functions: ["create", "get", "list", "paginate"]
  order_items:
    functions: ["create", "get"]

queries:
  directory: "./sql/queries"
```

### Query-Only (No Table Generation)

```yaml
database:
  dsn: "postgres://readonly:pass@replica:5432/analytics"

output:
  directory: "./queries/generated"
  package: "queries"

queries:
  directory: "./sql/reports"
```

### Multiple Schemas

Run skimatik multiple times with different configs:

```yaml
# config-public.yaml
database:
  dsn: "postgres://..."
  schema: "public"
output:
  directory: "./repos/public"
  package: "public"
tables:
  users:

# config-billing.yaml
database:
  dsn: "postgres://..."
  schema: "billing"
output:
  directory: "./repos/billing"
  package: "billing"
tables:
  invoices:
```

```bash
skimatik --config=config-public.yaml
skimatik --config=config-billing.yaml
```
