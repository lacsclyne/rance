# Assets

Reserved for source media such as art, audio, fonts, and UI reference files.
Do not add large binary assets or licensed material without a dedicated issue.

## Asset Manifest

Asset paths are reserved in [asset_manifest.json](asset_manifest.json). The
manifest is allowed to contain placeholders: a missing file only fails
validation when its entry sets `required` to `true`.

Each manifest entry uses these fields:

- `id`: stable asset ID in `<category>.<name>` format.
- `category`: one of `card_art`, `portrait`, `faction_icon`, `skill_icon`,
  `encounter_background`, or `ui`.
- `path`: repository-relative future file path using forward slashes.
- `required`: `true` only when the file must exist for the current build or
  content contract.
- `status`: `placeholder`, `draft`, or `final`.
- `source_id`: optional content ID the asset represents, such as
  `card.spark_bolt` or `character.iris`.

Validate the manifest with:

```sh
python tools/dev/validate_asset_manifest.py
```

## Directory Layout

- `card_art/`: card illustrations, manifest category `card_art`.
- `portraits/`: character portraits, manifest category `portrait`.
- `icons/factions/`: faction icons, manifest category `faction_icon`.
- `icons/skills/`: skill icons, manifest category `skill_icon`.
- `backgrounds/encounters/`: encounter and battle backgrounds, manifest
  category `encounter_background`.
- `ui/`: UI imagery such as frames, panels, logos, and reusable presentation
  assets, manifest category `ui`.

Future art issues should add or update the manifest entry in the same change as
the asset file. Keep placeholder entries `required: false`; switch to
`required: true` only when the referenced file is committed and runtime or
content validation depends on it.

Runtime code should resolve manifest IDs through
`src/resource_loading/resource_registry.gd` instead of hardcoding final art
paths in gameplay or UI modules.
