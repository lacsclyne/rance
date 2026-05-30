# Developer Tools

## Responsibility

Own developer-only scripts, data checks, conversion utilities, editor helpers,
and local validation commands.

## Future Code Paths

- `tools/dev/`
- Future editor-only scripts may be placed under a documented Godot editor
  tools path if a later issue creates one.

## Key Scene and Resource Paths

- No runtime scenes are reserved for this module.
- Tool fixtures should live under `tests/fixtures/` when they are used by
  automated validation.

## Interface Boundaries

- Tools may inspect or generate project data, but generated outputs must be
  reviewed and documented in the owning module.
- Do not add runtime dependencies from game code to `tools/dev/`.
- Do not introduce third-party plugins or large binaries without a dedicated
  issue.

## Current Validation Commands

- `python tools/dev/validate_content_data.py`
- `python tools/dev/validate_asset_manifest.py`

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/tests.md`
- `tools/README.md`
- `tools/dev/README.md`
