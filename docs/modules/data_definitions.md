# Data Definitions

## Responsibility

Own shared data models, schema validation, content import conventions, and
stable IDs used by gameplay modules.

## Future Code Paths

- `src/data/`
- `data/`

## Key Scene and Resource Paths

- Future content tables: `res://data/`
- Future typed resources: `res://resources/data/`

## Interface Boundaries

- Define shape and validation rules for data consumed by other modules.
- Do not implement card effects, combat resolution, event writing, or save slot
  persistence.
- Gameplay modules should depend on validated data contracts rather than parsing
  raw files themselves.
- `ContentDataLoader` reads JSON from `res://data/`, validates the first content
  contract, and returns raw dictionaries plus ID indexes for consumers.
- Loader validation covers required fields, ID uniqueness, cross-table
  references, asset manifest references, enum values, and basic numeric ranges.
  It does not interpret declarative effect, quest, progression, or reward
  behavior.

## Developer Validation

Use the Godot headless entrypoint when Godot is installed:

```sh
godot --headless --path . --script tools/dev/validate_content_data.gd
```

Use the Python fallback in environments without Godot:

```sh
python tools/dev/validate_content_data.py
```

Use `-- --data-root <path>` with the Godot script or `--data-root <path>` with
the Python fallback for validating copied fixture data.

## Content Authoring

Use [docs/content-authoring/README.md](../content-authoring/README.md) for
starter templates, required field notes, ID naming rules, reference fields, and
common validation errors.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/README.md`
- `src/data/README.md`
- `data/README.md`
