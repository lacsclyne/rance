# Data Definitions

`content_data_loader.gd` is the runtime-facing entry point for first-pass
content JSON loading and validation.

Use `ContentDataLoader.load_and_validate()` from Godot code to read the
collections under `res://data/`. The returned dictionary contains:

- `ok`: `true` when all files loaded and validation passed.
- `data`: raw parsed JSON dictionaries grouped by collection key.
- `indexes`: ID lookup dictionaries for validated top-level content rows.
- `errors`: messages that include file, content ID, field, and failure reason.

The loader validates required fields, stable ID format and uniqueness, enum
values, basic integer ranges, cross-table references, and optional asset
manifest references such as `portrait_asset_id` or `card_art_asset_id`. It does
not execute card effects, resolve combat, interpret quest flow, mutate saves,
or touch UI.

Developer validation commands are documented in `tools/dev/README.md`. See
`docs/modules/data_definitions.md` for module boundaries.
