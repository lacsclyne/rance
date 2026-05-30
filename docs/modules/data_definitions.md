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

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/README.md`
- `src/data/README.md`
- `data/README.md`
