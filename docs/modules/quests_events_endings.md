# Quests, Events, and Endings

## Responsibility

Own quest state, event routing, campaign flags, branch conditions, and ending
unlock contracts.

## Future Code Paths

- `src/quests_events_endings/`
- Content data under `data/quests/`, `data/events/`, and `data/endings/`

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

## Data Contracts

- Quests remain the battle/reward objective rows consumed by the current quest
  graph compatibility path.
- Events are campaign-scoped rows with trigger conditions for turn/deadline,
  faction/front state, quest state, character state, and prior flags. Event
  effects may set/clear flags, expose quests, or point at progression unlocks.
- Endings are campaign-scoped rows with priority and optional exclusive-group
  ordering. Requirements may reference quest outcomes, progression nodes,
  flags, character survival/availability, and faction state.
- Ending rows carry related faction/character IDs plus discovery and carryover
  hooks so future multi-run logic can record what the player has seen.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/strategy_map.md`
- `docs/modules/progression_carryover.md`
- `docs/modules/save_system.md`
- `src/quests_events_endings/README.md`
