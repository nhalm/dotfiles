# Building Command-Line Apps

Load this when building or extending a CLI. The universal golang-pro rules still apply; this adds CLI-specific structure. Built on cobra. Patterns here mirror the GitHub CLI (`gh`), which fits these conventions cleanly.

## Command Architecture

- **cobra, `noun verb` ordering** (`app payments list`, not `app list-payments`). One file per command. Group related subcommands in help. Flag names mean the same thing in every subcommand.
- **Separate flag-binding from logic.** `NewCmdX(f) *cobra.Command` constructs the command and binds flags into an `Options` struct; a pure `runX(ctx, opts) error` does the work. Test `runX` directly — no cobra in the test. (This is golang-pro's structs-over-params + testability applied to a CLI.)

```go
type Options struct {
    IO     *iostreams.IOStreams
    Client PaymentLister // consumer-defined interface
    Limit  int
    JSON   bool
}

func NewCmdList(f *Factory) *cobra.Command {
    opts := &Options{IO: f.IO}
    cmd := &cobra.Command{
        Use:   "list",
        Short: "List payments",
        RunE: func(cmd *cobra.Command, _ []string) error {
            opts.Client = f.PaymentClient()
            return runList(cmd.Context(), opts)
        },
    }
    cmd.Flags().IntVar(&opts.Limit, "limit", 20, "max results")
    cmd.Flags().BoolVar(&opts.JSON, "json", false, "output JSON")
    return cmd
}

func runList(ctx context.Context, opts *Options) error { /* pure logic */ }
```

- **Thread an `IOStreams` struct** (`In`, `Out`, `ErrOut`, `IsStdoutTTY()`, `IsStdinTTY()`) instead of touching `os.Stdout` directly. Construct a fake in tests to capture output. Detect TTY capability once, then branch output off it.
- **Wire dependencies top-down** through a small factory or explicit constructors — no globals (golang-pro DI). Clients/config/IO are lazily provided and swappable in tests.

## Output

- **stdout = primary, machine-consumable data only. stderr = everything else** — logs, errors, progress, prompts, status. Piping must yield clean data.
- **Auto-select format by destination:** table when stdout is a TTY, JSON when piped. `--json` / `-o json` forces JSON regardless. Keep success output brief; offer `-q/--quiet`.
- **Color is conditional:** disable when stdout/stderr isn't a TTY, `NO_COLOR` is set (any value), `TERM=dumb`, or `--no-color`. Disable spinners/animations off-TTY (they become junk in CI logs).

## Errors & Exit Codes

- **0 on success, non-zero on failure.** Document the codes you use; keep them stable (agents and scripts depend on them).
- **Rewrite expected errors for the operator** — say what failed and the fix ("can't write config.toml, try `chmod +w`"). No stack traces unless `--debug`/verbose.
- Map golang-pro **error categories** to exit behavior at the command boundary: a not-found sentinel → its own code, validation error → another. Errors print to stderr.

## Config, Flags & Interactivity

- **Precedence, highest to lowest:** flags > env vars > project config > user config > built-in defaults. Use XDG base dirs (`~/.config/<app>/`), not home-dir dotfiles.
- **Prefer flags to positional args.** Short+long for common flags; reuse standard names (`--all`, `-f/--force`, `-o/--output`, `-q/--quiet`, `-n/--dry-run`, `--no-input`). **Never accept secrets via flags** (they leak to process listings/history) — use env, a file, or stdin.
- **Interactive only when stdin is a TTY.** `--no-input`/`--yes` disable prompts; when input is required but absent, fail with a message naming the flag to set. `--dry-run` for any mutating command.

## Context, Signals & Cancellation

- Use `cmd.Context()` and pass it down (golang-pro context discipline).
- Trap `SIGINT`/`SIGTERM`, cancel the context, exit promptly; a second Ctrl-C forces immediate exit ("Stopping… press Ctrl-C again to force").
- Timeouts on every network call, configurable with a sane default.

## Testing CLIs

- Test `runX(ctx, opts)` directly: build an `Options` with a fake `IOStreams` and a mock of the consumer-defined client interface, run it, assert on captured stdout/stderr and the returned error. Table-driven.
- Golden/snapshot tests for rendered table and JSON output — on critical commands only, not everything.
- Don't test cobra, flag parsing internals, or generated mocks.

## Designing for AI Agents

When the CLI is meant to be driven by coding agents (Claude Code, Codex), headless determinism and a stable contract matter more than polish:

- **Deterministic headless behavior:** `--json`, `--no-input`/`--yes`, `--dry-run` for mutations, documented stable exit codes. An agent must never hit an interactive prompt.
- **`--json` output is a versioned contract.** Stable field names; additive changes only; don't rename or repurpose fields. Agents parse it programmatically.
- **Complete, example-led `--help` on every command.** Agents read `--help` to learn usage. Lead with examples. cobra's "did you mean" + usage-on-error aids recovery.
- **Ship an agent-facing usage doc (or a Claude skill) with the tool** encoding invariants the agent should follow: auth via env var, prefer `--json`, use `--dry-run` before mutations, how profiles / sub-account selection work.
- **Validate untrusted input at the boundary** — reject control chars and path traversal in IDs before they reach an HTTP path. This is exactly where validation belongs (not a violation of "don't over-defend internal code").
- **Optional, only on real need:** `--fields` masks and NDJSON pagination (`--page-all`, one object per line) to keep responses inside an agent's context window; a `schema` command exposing commands/flags/output types as JSON. Don't build these speculatively.
