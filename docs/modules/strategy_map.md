# Factions and Strategy Map

## Responsibility

Own faction state, regions, fronts, pressure clocks, map progression, and
campaign-level strategic outcomes.

## Future Code Paths

- `src/strategy_map/`
- Future content data under `data/factions/` and `data/strategy_map/`

## Current Runtime Entry Points

- `src/strategy_map/campaign_state.gd`
- `src/strategy_map/front_state.gd`
- `src/strategy_map/strategic_action.gd`

## Key Scene and Resource Paths

- Future map scenes: `res://scenes/strategy_map/`
- Future map resources: `res://resources/strategy_map/`

## Interface Boundaries

- May request quest/event triggers and battle entry points, but should not own
  quest text, combat resolution, card collection internals, or save I/O.
- Exposes campaign state snapshots for UI and save modules.
- Avoid placing one-off story branches here; those belong in quests, events, and
  endings.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/quests_events_endings.md`
- `docs/modules/combat.md`
- `docs/modules/save_system.md`
- `src/strategy_map/README.md`
