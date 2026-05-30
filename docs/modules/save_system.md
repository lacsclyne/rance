# Save System

## Responsibility

Own save slots, serialization, migrations, settings persistence, and recovery
rules for long campaign and carryover data.

## Current Code Paths

- `src/save/save_snapshot_contract.gd`
- `src/save/save_manager.gd`
- `tests/test_save_manager_minimal.gd`

## Key Scene and Resource Paths

- Future save metadata resources: `res://resources/save/`
- Future save/load UI scenes should live under `res://scenes/ui/`

## Interface Boundaries

- Stores state supplied by modules; it should not decide gameplay outcomes.
- Defines versioned persistence contracts for strategy, roster, quest,
  progression, settings, and run history data.
- Does not parse arbitrary module internals or write content data files.
- Tests must not write real player save files outside the repository.

## Versioned Snapshot Contract

The current save snapshot version is `1`. A snapshot is a JSON-friendly
dictionary with these top-level keys:

| Key | Owner | Notes |
| --- | --- | --- |
| `version` | Save system | Numeric contract version. Future versions migrate toward the current one. |
| `metadata` | Save system | Slot list metadata and summaries safe to read without interpreting gameplay state. |
| `campaign` | Campaign/strategy modules | Empty until campaign state has concrete snapshot fields. |
| `collection` | Cards and characters | Empty until collection state exports a persistence snapshot. |
| `formation` | Cards and characters | Empty until formation state exports a persistence snapshot. |
| `quest` | Quest run module | Empty until active quest state exports a persistence snapshot. |
| `progression` | Progression/carryover | Empty until unlock and carryover state exports a snapshot. |
| `settings` | Settings/config | Empty until settings persistence is implemented. |

The save manager normalizes missing optional section dictionaries to `{}` and
rejects snapshots from versions newer than it supports. The migration hook is
present but currently has no version-to-version steps because version `1` is
the first contract.

## Slot Metadata

`metadata` currently contains:

- `slot_id`: stable slot key supplied by the caller.
- `slot_label`: optional display label.
- `created_at` and `updated_at`: caller-supplied timestamps.
- `campaign_id`: optional campaign/content id for slot selection.
- `playtime_seconds`: numeric playtime summary.
- `summary`: compact JSON-friendly display summary.

Metadata may be extracted with `SaveManager.extract_slot_metadata()` after the
payload has passed version and shape validation.

## Serialization Rules

- `SaveManager.create_empty_save()` returns the current empty snapshot shape.
- `SaveManager.create_save()` accepts section dictionaries from other modules.
- `serialize_snapshot()` and `deserialize_snapshot()` operate on dictionaries;
  they do not touch disk or choose save paths.
- Payloads from future save versions fail with a clear mismatch error.
- Missing module sections are accepted and filled as empty dictionaries.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `docs/modules/progression_carryover.md`
- `docs/modules/boot_config.md`
- `src/save/README.md`
