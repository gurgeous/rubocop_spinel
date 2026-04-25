# AGENTS

## Priority

- This repo is a small RubyGems template, not a standalone app
- Prefer `just` over raw cli
- After changes, run `just check`
- Use `just fmt` / `just lint`, not rubocop or prettier directly
- Keep commit messages under 80 chars
- Fail fast; don't be overly defensive

## Layout

- Executables in `bin/`
- Support code and gem entrypoints in `lib/`
- Template placeholders should stay obvious and easy to replace

## Coding Style

- Be concise
- Favor early returns, functional/immutable helpers, minimal, golden path
- Keep code small, direct, and easy to scan
- Prefer symbol-keyed hashes
- Avoid `to_s` / `to_sym` churn unless it solves a real boundary problem
- Methods with >=3 args are a code smell; prefer `context:` / `options:` or refactor
- When using a shell, use argv arrays to avoid escaping issues
- Avoid compatibility class aliases

## Formatting

- Trivial methods can be one-liners, only if <100 chars
- Group several one-liners under `# one-liners` at bottom and alphabetize
- Use `_1` / `_2` for simple blocks when clear
- Add a short top-level comment to each source file
- Add brief comments only when they help

## Tests

- New behavior should usually come with tests
- Bug fixes should usually add or update a test
- Keep tests small and deterministic
- Mock/stub instead of dependency injection

## Defaults

- Match the repo's existing test style
- Prefer existing repo patterns over new abstractions
- Prefer straightforward over clever
- Keep comments light and useful
- Be conservative about adding deps or globals
