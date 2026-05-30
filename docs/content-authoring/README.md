# Content Authoring Guide

Use this guide when adding or revising JSON content under `data/`. The starter
templates in [templates/](templates/) mirror the current data layout and are
generic placeholders, not final character, story, ending, or balance decisions.

Use [art-intake-workflow.md](art-intake-workflow.md) when a content row needs a
generated or commissioned card illustration, portrait, icon, background, or UI
image tracked through the asset manifest.

## Template Index

| Content type | Data file | Schema | Template |
| --- | --- | --- | --- |
| Campaigns | `data/campaign/campaigns.json` | `data/schemas/campaign.schema.json` | [campaign/campaigns.json](templates/campaign/campaigns.json) |
| Factions | `data/factions/factions.json` | `data/schemas/factions.schema.json` | [factions/factions.json](templates/factions/factions.json) |
| Characters | `data/characters/characters.json` | `data/schemas/characters.schema.json` | [characters/characters.json](templates/characters/characters.json) |
| Cards | `data/cards/cards.json` | `data/schemas/cards.schema.json` | [cards/cards.json](templates/cards/cards.json) |
| Skills | `data/skills/skills.json` | `data/schemas/skills.schema.json` | [skills/skills.json](templates/skills/skills.json) |
| Statuses | `data/statuses/statuses.json` | `data/schemas/statuses.schema.json` | [statuses/statuses.json](templates/statuses/statuses.json) |
| Enemies | `data/enemies/enemies.json` | `data/schemas/enemies.schema.json` | [enemies/enemies.json](templates/enemies/enemies.json) |
| Encounters | `data/encounters/encounters.json` | `data/schemas/encounters.schema.json` | [encounters/encounters.json](templates/encounters/encounters.json) |
| Quests | `data/quests/quests.json` | `data/schemas/quests.schema.json` | [quests/quests.json](templates/quests/quests.json) |
| Reward pools | `data/reward_pools/reward_pools.json` | `data/schemas/reward_pools.schema.json` | [reward_pools/reward_pools.json](templates/reward_pools/reward_pools.json) |
| Progression nodes | `data/progression/progression.json` | `data/schemas/progression.schema.json` | [progression/progression.json](templates/progression/progression.json) |

There is no ending content template yet because the repository does not have an
ending schema or fixture collection yet.

## Authoring Flow

1. Copy the matching template row or file into the target `data/` collection.
2. Rename every `*.template_*` ID before committing.
3. Update any reference fields so they point to existing IDs in the matching
   collection.
4. Fill optional asset reference fields with stable manifest IDs from
   `assets/asset_manifest.json` when the content expects art.
5. Run validation:

```sh
python tools/dev/validate_content_data.py
```

If Godot is installed, the equivalent runtime-facing check is:

```sh
godot --headless --path . --script tools/dev/validate_content_data.gd
```

5. Run the advisory inventory report when checking MVP roster completeness:

```sh
python tools/dev/content_inventory_report.py
```

Read the `MVP Roster Coverage` section as a planning checklist, not a hard
content gate. It reports the current target of 2 roster factions, 3 characters
per faction, and 2 card versions per character, grouped by faction and
character. Missing character slots, missing card version slots, duplicate
version slots, design packet link gaps when those fields are present, and asset
reference gaps can be fixed over multiple content passes without requiring
final names, final art, or final balance values.

## ID Rules

- IDs use `<kind>.<name>` with lowercase ASCII letters, numbers, and
  underscores, for example `card.example_strike`.
- The `<kind>` prefix must match the collection: `card.`, `character.`,
  `enemy.`, `encounter.`, `faction.`, `quest.`, `reward_pool.`, `skill.`,
  `status.`, `progression.`, or `campaign.`.
- Campaign act IDs use `act.<name>`. Encounter intent IDs use `intent.<name>`.
- IDs must be unique across all loaded content files.
- Keep IDs stable after other content references them.

## Required Fields

Every collection file requires `version` and its plural array key. Each array
must contain at least one row.

| Content type | Required row fields |
| --- | --- |
| Campaigns | `id`, `name`, `entry_character_ids`, `acts` |
| Factions | `id`, `name`, `alignment`, `color` |
| Characters | `id`, `name`, `faction_id`, `role`, `base_stats`, `starting_deck`, `skill_ids` |
| Cards | `id`, `name`, `type`, `rarity`, `cost`, `target`, `effects` |
| Skills | `id`, `name`, `trigger`, `description` |
| Statuses | `id`, `name`, `polarity`, `stack_rule`, `default_duration`, `description`, `effect_type`, `numeric_value`, `tick_timing`, `expire_timing` |
| Enemies | `id`, `name`, `faction_id`, `rank`, `base_stats`, `skill_ids` |
| Encounters | `id`, `name`, `tier`, `waves`, `reward_pool_id` |
| Quests | `id`, `name`, `objective`, `encounter_ids`, `reward_pool_id` |
| Reward pools | `id`, `name`, `entries` |
| Progression nodes | `id`, `name`, `requires`, `unlocks` |

`base_stats` requires integer `hp`, `attack`, `defense`, and `speed`. `hp` must
be at least `1`; the other stat values must be at least `0`.

## Reference Fields

| Field | Must reference |
| --- | --- |
| `cards[].effects[].status_id` | `status.*` when present; `apply_status` effects require it |
| `skills[].status_ids[]` | `status.*` |
| `characters[].faction_id` | `faction.*` |
| `characters[].starting_deck[]` | `card.*` |
| `characters[].skill_ids[]` | `skill.*` |
| `enemies[].faction_id` | `faction.*` |
| `enemies[].skill_ids[]` | `skill.*` |
| `reward_pools[].entries[].content_id` | `card.*` when `kind` is `card`; `skill.*` when `kind` is `skill` |
| `encounters[].waves[].enemy_id` | `enemy.*` |
| `encounters[].reward_pool_id` | `reward_pool.*` |
| `quests[].encounter_ids[]` | `encounter.*` |
| `quests[].reward_pool_id` | `reward_pool.*` |
| `quests[].progression_reward_id` | `progression.*` when present |
| `progression_nodes[].requires[]` | `progression.*` |
| `progression_nodes[].unlocks[].content_id` | Matches `unlocks[].kind`: `character`, `card`, `skill`, `encounter`, or `quest` |
| `campaigns[].entry_character_ids[]` | `character.*` |
| `campaigns[].acts[].encounter_ids[]` | `encounter.*` |
| `campaigns[].acts[].quest_ids[]` | `quest.*` |
| `campaigns[].acts[].progression_gate_id` | `progression.*` when present |

## Asset Reference Fields

Asset fields are optional, but when present they must reference an entry in
`assets/asset_manifest.json` with the matching category. Placeholder manifest
entries are valid and should be used before final art exists.

| Field | Manifest category |
| --- | --- |
| `factions[].icon_asset_id` | `faction_icon` |
| `characters[].portrait_asset_id` | `portrait` |
| `cards[].card_art_asset_id` | `card_art` |
| `skills[].icon_asset_id` | `skill_icon` |
| `encounters[].background_asset_id` | `encounter_background` |

## Common Validation Errors

- `missing required field`: the row or nested object lacks a schema-required
  field.
- `must match <kind>.<name> lowercase ID format`: the ID has uppercase letters,
  a missing prefix, a hyphen, or no namespace dot.
- `must start with '<prefix>'`: the ID format is valid but the prefix does not
  match the collection.
- `duplicate ID`: the same ID appears twice in one collection or elsewhere in
  loaded content.
- `unknown ... id`: a reference field points at content that does not exist.
- `unknown asset id`: an asset reference field points at a manifest entry that
  does not exist.
- `expected asset category`: an asset reference field points at a manifest entry
  from the wrong category.
- `expected one of ...`: an enum field uses a value outside the schema.
- `must be >= ...`: an integer or number is below the schema minimum.
- `expected array` or `expected object`: a nested field has the wrong JSON type.
- `additionalProperties` failures in schema-aware editors usually mean the row
  contains a field that is not in the current schema.

## Template Validation

The template folder is shaped like a data root, so it can be smoke-tested
separately:

```sh
python tools/dev/validate_content_data.py --data-root docs/content-authoring/templates
```
