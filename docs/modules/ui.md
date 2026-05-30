# UI

## Responsibility

Own screen composition, reusable widgets, input presentation, view models, and
navigation between player-facing surfaces.

## Future Code Paths

- `src/ui/`
- Future UI scenes under `scenes/ui/`

## Key Scene and Resource Paths

- Future screen scenes: `res://scenes/ui/`
- Future UI resources: `res://resources/ui/`
- Future source media: `res://assets/ui/`

## Interface Boundaries

- UI displays state and sends user intent to domain modules through explicit
  APIs.
- UI does not own campaign simulation, battle rules, save migrations, data
  validation, or content authoring.
- Domain modules should remain testable without UI scenes loaded.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/boot_config.md`
- `docs/modules/resource_loading.md`
- `src/ui/README.md`
- `scenes/README.md`
