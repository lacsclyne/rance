# Content Data

This directory contains versioned, data-only fixtures for the first content
contract pass. It does not include Godot scenes, scripts, UI, save code, combat
logic, or runtime loaders.

For new content authoring, start with the guide and starter templates in
[docs/content-authoring/](../docs/content-authoring/README.md).

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
- `events/`: campaign event trigger and effect fixtures.
- `endings/`: ending requirement, ordering, discovery, and presentation fixtures.
- `reward_pools/`: weighted reward options.
- `progression/`: unlock nodes and gate references.

## Fixture Counts

- Campaigns: 1
- Factions: 3
- Characters: 5
- Cards: 10
- Skills: 10
- Statuses: 6
- Enemies: 4
- Encounters: 3
- Quests: 3
- Campaign events: 1
- Endings: 1
- Reward pools: 2
- Progression nodes: 4

## Field Conventions

- IDs use the format `<kind>.<name>` with lowercase ASCII letters, numbers, and
  underscores.
- Each collection file has a top-level `version` integer and one plural array
  named for the collection, such as `cards`, `characters`, or `reward_pools`.
- References use explicit `*_id` or `*_ids` fields and must point to IDs in the
  matching fixture collection.
- Asset references use explicit `*_asset_id` fields and must point to IDs in
  `assets/asset_manifest.json` with the expected manifest category. Placeholder
  manifest entries are valid; content should not reference asset file paths.
- Status rows include runtime effect metadata (`effect_type`, `numeric_value`,
  `tick_timing`, and `expire_timing`) consumed by the first combat resolver.
- Card `effects`, skill triggers, status stack rules, enemy notes, encounter
  intent patterns, encounter waves, quest objectives, campaign event triggers,
  ending requirements, reward pool entries, and progression unlocks are
  declarative descriptors only. Later runtime issues can interpret them without
  changing the IDs.

Examples:

- `character.iris`
- `card.spark_bolt`
- `reward_pool.prologue`

The current fixtures are intentionally small and stable so later gameplay and
editor tasks can depend on predictable IDs.
