# Content Data

This directory contains versioned, data-only fixtures for the first content
contract pass. It does not include Godot scenes, scripts, UI, save code, combat
logic, or runtime loaders.

## Layout

- `schemas/`: JSON Schema documents for each fixture collection.
- `campaign/`: campaign shell and act ordering.
- `factions/`: faction definitions.
- `characters/`: playable character definitions and starter decks.
- `cards/`: card definitions and effect descriptors.
- `skills/`: passive and active skill definitions.
- `statuses/`: status effect definitions.
- `enemies/`: enemy definitions and action references.
- `encounters/`: enemy wave and reward references.
- `quests/`: quest objectives and rewards.
- `reward_pools/`: weighted reward options.
- `progression/`: unlock nodes and gate references.

## Fixture Counts

- Campaigns: 1
- Factions: 3
- Characters: 5
- Cards: 10
- Skills: 10
- Statuses: 6
- Enemies: 3
- Encounters: 3
- Quests: 3
- Reward pools: 2
- Progression nodes: 4

## Field Conventions

- IDs use the format `<kind>.<name>` with lowercase ASCII letters, numbers, and
  underscores.
- Each collection file has a top-level `version` integer and one plural array
  named for the collection, such as `cards`, `characters`, or `reward_pools`.
- References use explicit `*_id` or `*_ids` fields and must point to IDs in the
  matching fixture collection.
- Card `effects`, skill triggers, status stack rules, enemy intents, encounter
  waves, quest objectives, reward pool entries, and progression unlocks are
  declarative descriptors only. Later runtime issues can interpret them without
  changing the IDs.

Examples:

- `character.iris`
- `card.spark_bolt`
- `reward_pool.prologue`

The current fixtures are intentionally small and stable so later gameplay and
editor tasks can depend on predictable IDs.
