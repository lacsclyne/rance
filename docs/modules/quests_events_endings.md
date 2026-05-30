# Quests, Events, and Endings

## Responsibility

Own quest state, event routing, campaign flags, branch conditions, and ending
unlock contracts.

## Future Code Paths

- `src/quests_events_endings/`
- Future content data under `data/quests/`, `data/events/`, and `data/endings/`

## Key Scene and Resource Paths

- Future event resources: `res://resources/events/`
- Future ending resources: `res://resources/endings/`
- UI presentation scenes should live under `res://scenes/ui/` unless a later
  issue creates a dedicated narrative scene area.

## Interface Boundaries

- Reads strategy, roster, progression, and save state through published
  contracts.
- Does not implement battle mechanics, card effects, map simulation, or text
  rendering widgets.
- Ending data must remain original and must not copy proprietary scenario text.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/strategy_map.md`
- `docs/modules/progression_carryover.md`
- `docs/modules/save_system.md`
- `src/quests_events_endings/README.md`
