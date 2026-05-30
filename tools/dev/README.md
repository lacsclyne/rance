# Developer Tools

Local validation, data conversion, editor helpers, and debug-only tools live
here. See `docs/modules/dev_tools.md`.

## Content Data Validation

Preferred Godot entrypoint:

```sh
godot --headless --path . --script tools/dev/validate_content_data.gd
```

This calls `src/data/content_data_loader.gd` and validates the JSON fixtures in
`res://data/`.

Fallback for workstations or CI runners without a Godot binary:

```sh
python tools/dev/validate_content_data.py
```

Both commands report failures with file, content ID, field, and reason. Use
`-- --data-root <path>` with the Godot script or `--data-root <path>` with the
Python script to validate a copied or generated data directory.

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
