# Combat System

## Responsibility

Own battle state, battle flow, targeting contracts, turn or phase sequencing,
and combat result summaries.

## Future Code Paths

- `src/combat/`
- Future content data under `data/combat/`

## Key Scene and Resource Paths

- Future battle scenes: `res://scenes/combat/`
- Future combat resources: `res://resources/combat/`

## Interface Boundaries

- Consumes card, character, enemy, and encounter data through data-definition
  contracts.
- Emits battle results to strategy, progression, quest, and save modules.
- Does not own long-term campaign simulation, card collection persistence, UI
  screen composition, or narrative content.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `docs/modules/cards_characters.md`
- `docs/modules/progression_carryover.md`
- `src/combat/README.md`
