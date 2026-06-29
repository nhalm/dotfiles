---
name: golang-pro
description: Rules for writing and testing Go the way this user wants — any over interface{}, consumer-defined interfaces, gomock with mocks beside the interface, table-driven tests, error categories with detail, context discipline, and testing only critical paths. Triggers whenever writing, structuring, reviewing, or testing Go (.go) code, including building command-line apps (cobra command structure, human-vs-machine output, exit codes, designing for AI agents — see cli.md).
model: sonnet
---

# golang-pro

A set of rules for writing and testing Go. Follow them exactly — they override generic Go habits. This is conventions, not architecture; it does not mandate a project layout or library stack.

**Building a command-line app?** Also read `cli.md` — cobra command structure, the Options-struct + pure-run split, IOStreams, human-vs-machine output, exit codes, config precedence, and designing for AI agents.

## Interfaces & Types

- **`any`, never `interface{}`.** For the empty interface, always write `any`.
- **Interfaces are defined by the consumer, not the provider.** The package that *uses* a dependency declares the narrow interface listing only the methods it calls. Provider packages export concrete types and real implementations — they do not define interfaces for their callers.
- **Accept interfaces, return concrete types.** Constructors and functions return concrete structs; callers depend on the interface they declared.
- **Keep interfaces small.** One- and two-method interfaces are the norm. Name them for what they do (`PaymentLister`), not what they are (`PaymentServiceInterface`).

## Signatures & Configuration

- **Prefer a struct over a long parameter list.** When a function takes more than a couple of related arguments, pass a single params/request struct. Named fields beat positional args — they document intent and survive added fields without breaking callers.
- **Configure with fluent APIs.** Expose optional configuration as functional options (`WithTimeout(d)`, `WithRetries(n)`) or chained builder methods that return the receiver — not bare optional parameters or an exported struct callers mutate. The zero value should be usable; options layer on top.

## Errors

- **Wrap with `%w`, inspect with `errors.Is` / `errors.As`.** Never compare error strings. Add context describing what you were doing: `fmt.Errorf("list payments: %w", err)`.
- **Use error categories that carry detail.** Define sentinel errors for the categories callers branch on (`ErrNotFound`, `ErrAlreadyExists`, `ErrInvalidInput`, …). When callers need specifics, use a typed error carrying fields — e.g. a `ValidationError` with per-field `{Field, Code, Message}`. The category drives control flow via `errors.Is`; the detail informs the response. Each layer translates lower-layer errors into its own category vocabulary.
- **No panics in library/CLI code.** Return errors; reserve `panic` for genuinely unreachable states.
- **Handle each error once** — either log it or return it, not both.

## Context

- **`context.Context` is the first parameter** of any function doing I/O, crossing a boundary, or potentially blocking.
- **Never store a `Context` in a struct.** Pass it through call chains.
- **Propagate the incoming context.** Don't fabricate `context.Background()` mid-call; derive (`context.WithTimeout`, `WithValue`) from the one you were given.

## Testing

- **Table-driven tests.** One case per row; each row brings its own setup and expectation. Run with `t.Run(tt.name, ...)`. Prefer `wantErr error` over `bool` so a case can assert the exact sentinel.
- **Mocks via gomock, generated.** Never hand-write a mock. The `//go:generate mockgen` directive sits on the interface file; the generated mock lives **in the same package as the interface it implements** (which, per consumer-owned interfaces, is the consumer's package).
- **Never test a mock.** A test asserting a mock returns what it was told to return verifies nothing. Because mocks are regenerated from the interface, they cannot drift — so there is no need for contract/consistency tests comparing a mock to the real implementation. Test the real implementation directly (e.g. an HTTP client against `httptest.Server`, a repository against a real DB).
- **Test critical paths only.** Cover the behavior that would cause a production bug if broken: business logic, error translation, edge cases that are actually reachable. Do not write tests to chase a coverage percentage, and skip trivial accessors, constructors, generated code, and framework behavior.
- **Hygiene:** call `t.Helper()` in test helpers; use `t.Parallel()` where cases are independent; use testify `require` to stop on a failed precondition and `assert` for independent checks. Never synchronize tests with `time.Sleep` — wait on a condition/channel.
- **Performance tests only when necessary.** Write benchmarks or query-plan/golden tests for load-bearing hot paths where a regression would actually hurt — not reflexively.

## Idioms

- **Don't write overly defensive code.** Validate at boundaries (untrusted input, API edges), then trust internal invariants. Don't add nil checks, re-validation, or guards for states your own code makes impossible — they add noise and hide real bugs. Passing values (not pointers) across boundaries removes most nil paths to begin with.
- **Early returns over nested `if`/`else`.** Keep the happy path at minimal indentation.
- **godoc on exported symbols.** Package-level and exported identifiers get a doc comment starting with the symbol name. Avoid inline comments that restate the code.
- **Prefer the standard library; minimize dependencies.** Reach for a third-party package only when it earns its place.
- **`gofmt`/`goimports` always; lint clean.** Fix lint findings rather than suppressing them; when a suppression is truly warranted, scope it to the line with `//nolint:<rule> // <rationale>`.
