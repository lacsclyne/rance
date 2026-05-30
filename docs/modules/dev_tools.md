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

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/tests.md`
- `tools/README.md`
- `tools/dev/README.md`

## Current Commands

- Validate content fixtures with Godot:
  `godot --headless --path . --script tools/dev/validate_content_data.gd`
- Validate content fixtures without Godot:
  `python tools/dev/validate_content_data.py`
- Report content inventory counts, summaries, placeholder strings, and
  validation-derived missing references:
  `python tools/dev/content_inventory_report.py`
- Write the inventory report as JSON:
  `python tools/dev/content_inventory_report.py --json-output content-inventory.json`
