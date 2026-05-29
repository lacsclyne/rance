# Tests

## Responsibility

Own automated tests, fixtures, validation scripts, and headless Godot test
entry points once a test framework is selected.

## Future Code Paths

- `tests/`
- Future fixtures under `tests/fixtures/`
- Future test helpers under `tests/helpers/`

## Key Scene and Resource Paths

- Future test runner scene: `res://tests/test_runner.tscn`
- Future fixtures: `res://tests/fixtures/`

## Interface Boundaries

- Tests may exercise every module, but production modules must not depend on
  test code.
- Shared test helpers belong in `tests/helpers/`, not inside runtime module
  directories.
- Validation commands must be recorded in PRs and in this document when they
  become standard.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/dev_tools.md`
- `tests/README.md`
