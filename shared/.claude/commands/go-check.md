Run Go formatting and linting with auto-fix enabled.

1. Run `gofmt -w .` to format all Go files in place
2. Run `golangci-lint run --fix` to auto-fix linter issues where possible
3. If any remaining linter issues cannot be auto-fixed, list them clearly

If golangci-lint is not installed, install it first with `brew install golangci-lint`.

Focus on: $ARGUMENTS
