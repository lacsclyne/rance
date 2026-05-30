# Resource Loading

Resource lookup, cache policy metadata, and content loading service code lives
here. See `docs/modules/resource_loading.md`.

## Current Scripts

- `resource_registry.gd` exposes `ResourceRegistry`, an in-memory stable-ID
  registry for lightweight lookup by ID, resource type, and Godot path.

## Manifest Adapter Point

No asset manifest schema is defined in this module. If the LAC-28 manifest
exists, adapt it inside `ResourceRegistry.load_from_asset_manifest()` rather
than creating another manifest format.

The registry stores cache policy placeholders but does not load resources or
start async work.
