# Save System

## Responsibility

Own save slots, serialization, migrations, settings persistence, and recovery
rules for long campaign and carryover data.

## Future Code Paths

- `src/save/`

## Key Scene and Resource Paths

- Future save metadata resources: `res://resources/save/`
- Future save/load UI scenes should live under `res://scenes/ui/`

## Interface Boundaries

- Stores state supplied by modules; it should not decide gameplay outcomes.
- Defines versioned persistence contracts for strategy, roster, quest,
  progression, settings, and run history data.
- Does not parse arbitrary module internals or write content data files.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `docs/modules/progression_carryover.md`
- `docs/modules/boot_config.md`
- `src/save/README.md`
