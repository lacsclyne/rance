# Save

Pure-logic save contracts and helpers live here. The save module does not write
player files yet and is not registered as an autoload.

## Scripts

- `save_snapshot_contract.gd`: versioned snapshot shape, default section and
  metadata dictionaries, and migration placeholders.
- `save_manager.gd`: service wrapper for creating empty saves, serializing a
  normalized dictionary payload, deserializing one, and extracting slot metadata.

## Snapshot Shape

Version `1` snapshots are JSON-friendly dictionaries:

```gdscript
{
	"version": 1,
	"metadata": {
		"slot_id": "",
		"slot_label": "",
		"created_at": "",
		"updated_at": "",
		"campaign_id": "",
		"playtime_seconds": 0,
		"summary": {}
	},
	"campaign": {},
	"collection": {},
	"formation": {},
	"quest": {},
	"progression": {},
	"settings": {}
}
```

The section dictionaries are intentionally empty by default. Gameplay modules
own the contents of their section snapshots and should keep those contents
JSON-friendly.

## Validation

```sh
godot --headless --path . --script tests/test_save_manager_minimal.gd
```

See `docs/modules/save_system.md` for the module boundary.
