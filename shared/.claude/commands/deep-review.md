Perform a comprehensive code review by launching these agents IN PARALLEL using the Task tool:

1. **code-reviewer agent**: Review code for quality, security issues, and anti-patterns
2. **golang-pro agent** (if Go project): Run `gofmt -w .` and `golangci-lint run --fix`, report any remaining issues
3. **python-dev agent** (if Python project): Run formatters (black, ruff) and linters with auto-fix
4. **docs-researcher agent**: Review documentation for accuracy, completeness, and alignment with code
5. **dx-optimizer agent**: Evaluate developer experience - README clarity, setup process, tooling, and workflow friction

IMPORTANT: Launch all relevant agents concurrently in a single message with multiple Task tool calls. Skip language-specific agents that don't apply to this project.
Do NOT put much effort into a code coverage percentage, what matters is that we cover critical code paths with tests.

After all agents complete, provide a unified summary organized by category:
- Critical issues requiring immediate attention
- Code quality findings
- Documentation gaps
- DX improvements

Scope: $ARGUMENTS
