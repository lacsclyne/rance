# System Clone Plan

This plan captures the data layer needed before implementing gameplay. It is a
small content clone of the intended RPG card battle systems: enough structure to
exercise IDs, references, and fixture loading without adding runtime code.

## Data Model

| Area | Fixture file | Schema | Count |
| --- | --- | --- | --- |
| Campaign | `data/campaign/campaigns.json` | `data/schemas/campaign.schema.json` | 1 |
| Factions | `data/factions/factions.json` | `data/schemas/factions.schema.json` | 3 |
| Characters | `data/characters/characters.json` | `data/schemas/characters.schema.json` | 5 |
| Cards | `data/cards/cards.json` | `data/schemas/cards.schema.json` | 10 |
| Skills | `data/skills/skills.json` | `data/schemas/skills.schema.json` | 10 |
| Statuses | `data/statuses/statuses.json` | `data/schemas/statuses.schema.json` | 6 |
| Enemies | `data/enemies/enemies.json` | `data/schemas/enemies.schema.json` | 4 |
| Encounters | `data/encounters/encounters.json` | `data/schemas/encounters.schema.json` | 3 |
| Quests | `data/quests/quests.json` | `data/schemas/quests.schema.json` | 2 |
| Reward pools | `data/reward_pools/reward_pools.json` | `data/schemas/reward_pools.schema.json` | 1 |
| Progression | `data/progression/progression.json` | `data/schemas/progression.schema.json` | 3 |

## Conventions

- Content IDs are lowercase and stable: `<kind>.<name>`.
- Collections are grouped by content type so Godot import tasks can load only
  the data they need.
- Cross-file references use IDs instead of embedded objects.
- Effects are declarative descriptors, not executable behavior.
- Schemas validate document shape; a later tooling task can add full JSON Schema
  validation in CI.

## Reference Graph

- Characters reference factions, starter cards, and skills.
- Cards and skills may reference statuses.
- Enemies reference skills.
- Encounters reference enemies and reward pools.
- Quests reference encounters and reward pools.
- Campaigns reference characters, encounters, quests, and progression gates.
- Progression nodes reference unlockable characters, cards, skills, encounters,
  and quests.

## Out Of Scope

- Godot scenes, scripts, and import pipelines.
- Combat resolution, card execution, AI, and UI.
- GitHub Actions or Symphony workflow documentation.
