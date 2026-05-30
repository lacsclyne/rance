# Resource Loading

## Responsibility

Own resource lookup, cache policy, loading paths, and future async loading
services for content and assets.

## Future Code Paths

- `src/resource_loading/`
- `resources/`
- `assets/`

## Key Scene and Resource Paths

- Future loader resources: `res://resources/loaders/`
- Static content roots: `res://data/`, `res://resources/`, and `res://assets/`

## Interface Boundaries

- Provides loading services and typed handles; it does not own the meaning of
  loaded gameplay data.
- Should not implement combat, card, quest, strategy, or save rules.
- Modules should avoid direct ad hoc file parsing when a loader contract exists.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `resources/README.md`
- `assets/README.md`
- `src/resource_loading/README.md`
