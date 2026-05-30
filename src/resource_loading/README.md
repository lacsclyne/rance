# Resource Loading

Resource lookup, cache policy metadata, and content loading service code lives
here. See `docs/modules/resource_loading.md`.

## Current Scripts

- `resource_registry.gd` exposes `ResourceRegistry`, an in-memory stable-ID
  registry for lightweight lookup by ID, resource type, and Godot path.

## Manifest Adapter Point

`ResourceRegistry.load_from_asset_manifest()` reads the LAC-28 manifest at
`res://assets/asset_manifest.json`. It converts repository-relative manifest
paths into Godot `res://` paths and stores manifest-only fields as metadata.

The registry stores cache policy placeholders but does not load resources or
start async work. Do not add another manifest format in this module.
