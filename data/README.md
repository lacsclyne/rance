# Content Data

This directory contains data-only fixtures for the first 2D RPG card battle
prototype pass. It does not include Godot scenes, scripts, UI, or combat logic.

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
- Quests: 2
- Reward pools: 1
- Progression nodes: 3

## ID Rules

IDs use the format `<kind>.<name>` with lowercase ASCII letters, numbers, and
underscores. References must point to IDs in the matching fixture collection.

Examples:

- `character.iris`
- `card.spark_bolt`
- `reward_pool.prologue`

The current fixtures are intentionally small and stable so later gameplay and
editor tasks can depend on predictable IDs.
