# Developer Tools

Local validation, data conversion, editor helpers, and debug-only tools live
here. See `docs/modules/dev_tools.md`.

## Content Data Validation

Preferred Godot entrypoint:

```sh
godot --headless --path . --script tools/dev/validate_content_data.gd
```

This calls `src/data/content_data_loader.gd` and validates the JSON fixtures in
`res://data/`, including optional content-to-asset manifest references.

Fallback for workstations or CI runners without a Godot binary:

```sh
python tools/dev/validate_content_data.py
```

Both commands report failures with file, content ID, field, and reason. Use
`-- --data-root <path>` with the Godot script or `--data-root <path>` with the
Python script to validate a copied or generated data directory.

Use `--asset-manifest <path>` when validating against a non-default copy of
`assets/asset_manifest.json`.

## Build Export Validation

Minimal local Windows desktop export smoke check:

```sh
python tools/dev/validate_build_export.py
```

The script looks for Godot through `GODOT_BIN`, `--godot <path>`, or `PATH`, then
runs the `Windows Desktop` debug export preset into `build/dev/windows/`. The
`build/` directory is ignored by git and must not be committed.

If Godot is installed but export templates are missing, the script exits with a
clear message to install templates that match the local Godot version. To only
check that the project loads headlessly, run:

```sh
python tools/dev/validate_build_export.py --dry-run
```

Future Linux and Web exports should get their own presets after those target
platforms are selected and validated on a matching workstation or CI runner.

## Asset Manifest Validation

Validate reserved art and UI asset paths with:

```sh
python tools/dev/validate_asset_manifest.py
```

The validator checks `assets/asset_manifest.json` for required fields,
duplicate IDs, category/path naming consistency, and file existence only for
entries marked `required: true`. Placeholder entries may point to future files.

## Content Inventory Report

Generate a readable content inventory and validation summary:

```sh
python tools/dev/content_inventory_report.py
```

Write the same report as JSON for other tools:

```sh
python tools/dev/content_inventory_report.py --json-output content-inventory.json
```

Use `--data-root <path>` to scan another data directory and `--strict` to return
a non-zero exit code when validation errors are present.
