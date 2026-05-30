# Tests

## Responsibility

Own automated tests, fixtures, validation scripts, and headless Godot test
entry points once a test framework is selected.

## Future Code Paths

- `tests/`
- Future fixtures under `tests/fixtures/`
- Future test helpers under `tests/helpers/`
- Headless E2E smoke coverage under `tests/e2e/`

## Key Scene and Resource Paths

- Future test runner scene: `res://tests/test_runner.tscn`
- Future fixtures: `res://tests/fixtures/`

## Current Headless Checks

```sh
godot --headless --path . --script tests/test_combat_minimal.gd
godot --headless --path . --script tests/test_quest_graph_minimal.gd
godot --headless --path . --script tests/test_campaign_fronts_minimal.gd
godot --headless --path . --script tests/test_resource_registry.gd
godot --headless --path . --script tests/e2e/test_headless_mvp_loop.gd
```

## Related Local Validation

```sh
python tools/dev/validate_build_export.py
```

This checks the local desktop export path and reports missing Godot export
templates as a workstation setup issue.

## Interface Boundaries

- Tests may exercise every module, but production modules must not depend on
  test code.
- Shared test helpers belong in `tests/helpers/`, not inside runtime module
  directories.
- Validation commands must be recorded in PRs and in this document when they
  become standard.
- `tests/e2e/test_headless_mvp_loop.gd` covers the current non-UI MVP loop from
  loaded content through collection, formation, quest reward selection, and
  combat settlement. It does not cover UI scenes, art, user decision handling,
  campaign-front pressure APIs, or broad balance tuning.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/dev_tools.md`
- `tests/README.md`
