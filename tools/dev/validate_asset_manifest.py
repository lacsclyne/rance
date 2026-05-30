#!/usr/bin/env python3
"""Validate asset manifest structure and placeholder-safe paths."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any


ID_RE = re.compile(r"^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$")
STATUSES = {"placeholder", "draft", "final"}
ALLOWED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".aseprite", ".kra", ".psd"}

CATEGORY_RULES = {
    "card_art": {
        "id_prefix": "card_art.",
        "path_prefix": "assets/card_art/",
        "source_prefix": "card.",
    },
    "portrait": {
        "id_prefix": "portrait.",
        "path_prefix": "assets/portraits/",
        "source_prefix": "character.",
    },
    "faction_icon": {
        "id_prefix": "faction_icon.",
        "path_prefix": "assets/icons/factions/",
        "source_prefix": "faction.",
    },
    "skill_icon": {
        "id_prefix": "skill_icon.",
        "path_prefix": "assets/icons/skills/",
        "source_prefix": "skill.",
    },
    "encounter_background": {
        "id_prefix": "encounter_background.",
        "path_prefix": "assets/backgrounds/encounters/",
        "source_prefix": "encounter.",
    },
    "ui": {
        "id_prefix": "ui.",
        "path_prefix": "assets/ui/",
        "source_prefix": "",
    },
}

REQUIRED_ENTRY_FIELDS = ["id", "category", "path", "required", "status"]


class AssetManifestValidator:
    def __init__(self, manifest_path: Path, repo_root: Path) -> None:
        self.manifest_path = manifest_path
        self.repo_root = repo_root
        self.errors: list[str] = []
        self.asset_count = 0
        self.required_count = 0
        self._seen_ids: dict[str, str] = {}

    def run(self) -> bool:
        document = self._load_document()
        if document is None:
            return False

        if not isinstance(document, dict):
            self._error("<file>", "<root>", "expected JSON object")
            return False

        self._validate_version(document)
        assets = document.get("assets")
        if not isinstance(assets, list):
            self._error("<file>", "assets", "missing or invalid assets array")
            return False

        for index, entry in enumerate(assets):
            self.asset_count += 1
            self._validate_entry(entry, index)

        return not self.errors

    def _load_document(self) -> Any | None:
        if not self.manifest_path.exists():
            self._error("<file>", "<file>", "missing asset manifest")
            return None

        try:
            with self.manifest_path.open("r", encoding="utf-8-sig") as handle:
                return json.load(handle)
        except json.JSONDecodeError as exc:
            self._error("<json>", "<json>", f"parse error at line {exc.lineno}: {exc.msg}")
        except OSError as exc:
            self._error("<file>", "<file>", f"could not open file: {exc}")
        return None

    def _validate_version(self, document: dict[str, Any]) -> None:
        version = document.get("version")
        if not isinstance(version, int) or isinstance(version, bool):
            self._error("<file>", "version", "missing or invalid integer version")
        elif version < 1:
            self._error("<file>", "version", "must be >= 1")

    def _validate_entry(self, entry: Any, index: int) -> None:
        row_id = self._row_label(entry, index)
        if not isinstance(entry, dict):
            self._error(row_id, f"assets[{index}]", "expected object")
            return

        for field in REQUIRED_ENTRY_FIELDS:
            if field not in entry:
                self._error(row_id, field, "missing required field")

        asset_id = self._validate_id(entry.get("id"), row_id)
        category = self._validate_category(entry.get("category"), row_id)
        asset_path = self._validate_path_value(entry.get("path"), row_id)
        required = self._validate_required(entry.get("required"), row_id)
        self._validate_status(entry.get("status"), row_id)
        source_id = self._validate_optional_source_id(entry.get("source_id"), row_id)

        if asset_id and asset_id in self._seen_ids:
            self._error(row_id, "id", f"duplicate ID also appears at {self._seen_ids[asset_id]}")
        elif asset_id:
            self._seen_ids[asset_id] = f"assets[{index}]"

        if category and asset_id:
            self._validate_id_category(asset_id, category, row_id)
        if category and asset_path:
            self._validate_path_category(asset_path, category, row_id)
        if asset_id and asset_path:
            self._validate_id_path(asset_id, asset_path, row_id)
        if category and asset_id and source_id:
            self._validate_source_id(category, asset_id, source_id, row_id)
        if asset_path:
            self._validate_path_existence(asset_path, required, row_id)

    def _validate_id(self, value: Any, row_id: str) -> str:
        if not isinstance(value, str):
            self._error(row_id, "id", "expected string")
            return ""
        if not ID_RE.fullmatch(value):
            self._error(row_id, "id", "must match <kind>.<name> lowercase ID format")
            return ""
        return value

    def _validate_category(self, value: Any, row_id: str) -> str:
        if not isinstance(value, str):
            self._error(row_id, "category", "expected string")
            return ""
        if value not in CATEGORY_RULES:
            self._error(row_id, "category", f"expected one of {sorted(CATEGORY_RULES)}")
            return ""
        return value

    def _validate_path_value(self, value: Any, row_id: str) -> str:
        if not isinstance(value, str):
            self._error(row_id, "path", "expected string")
            return ""
        if value == "":
            self._error(row_id, "path", "must not be empty")
            return ""
        if "\\" in value:
            self._error(row_id, "path", "must use forward slashes")
        path = PurePosixPath(value)
        if path.is_absolute() or ".." in path.parts:
            self._error(row_id, "path", "must be a repository-relative path without '..'")
        if path.suffix.lower() not in ALLOWED_EXTENSIONS:
            self._error(row_id, "path", f"extension must be one of {sorted(ALLOWED_EXTENSIONS)}")
        for part in path.parts:
            if not re.fullmatch(r"[a-z0-9_.-]+", part):
                self._error(row_id, "path", "path segments must use lowercase ASCII, numbers, dots, dashes, or underscores")
                break
        return value

    def _validate_required(self, value: Any, row_id: str) -> bool:
        if not isinstance(value, bool):
            self._error(row_id, "required", "expected boolean")
            return False
        if value:
            self.required_count += 1
        return value

    def _validate_status(self, value: Any, row_id: str) -> None:
        if not isinstance(value, str):
            self._error(row_id, "status", "expected string")
            return
        if value not in STATUSES:
            self._error(row_id, "status", f"expected one of {sorted(STATUSES)}")

    def _validate_optional_source_id(self, value: Any, row_id: str) -> str:
        if value is None:
            return ""
        if not isinstance(value, str):
            self._error(row_id, "source_id", "expected string")
            return ""
        if not ID_RE.fullmatch(value):
            self._error(row_id, "source_id", "must match <kind>.<name> lowercase ID format")
            return ""
        return value

    def _validate_id_category(self, asset_id: str, category: str, row_id: str) -> None:
        expected = CATEGORY_RULES[category]["id_prefix"]
        if not asset_id.startswith(expected):
            self._error(row_id, "id", f"must start with '{expected}' for category '{category}'")

    def _validate_path_category(self, asset_path: str, category: str, row_id: str) -> None:
        expected = CATEGORY_RULES[category]["path_prefix"]
        if not asset_path.startswith(expected):
            self._error(row_id, "path", f"must start with '{expected}' for category '{category}'")

    def _validate_id_path(self, asset_id: str, asset_path: str, row_id: str) -> None:
        expected_stem = asset_id.split(".", 1)[1]
        actual_stem = PurePosixPath(asset_path).stem
        if actual_stem != expected_stem:
            self._error(row_id, "path", f"file stem must match asset ID suffix '{expected_stem}'")

    def _validate_source_id(self, category: str, asset_id: str, source_id: str, row_id: str) -> None:
        expected_prefix = CATEGORY_RULES[category]["source_prefix"]
        if expected_prefix and not source_id.startswith(expected_prefix):
            self._error(row_id, "source_id", f"must start with '{expected_prefix}' for category '{category}'")
            return
        if expected_prefix and source_id.split(".", 1)[1] != asset_id.split(".", 1)[1]:
            self._error(row_id, "source_id", "suffix must match asset ID suffix")

    def _validate_path_existence(self, asset_path: str, required: bool, row_id: str) -> None:
        resolved = (self.repo_root / Path(*PurePosixPath(asset_path).parts)).resolve()
        repo_root = self.repo_root.resolve()
        try:
            resolved.relative_to(repo_root)
        except ValueError:
            self._error(row_id, "path", "resolved path must stay inside the repository")
            return

        if resolved.exists() and not resolved.is_file():
            self._error(row_id, "path", "resolved path exists but is not a file")
        if required and not resolved.is_file():
            self._error(row_id, "path", "required asset file does not exist")

    def _row_label(self, entry: Any, index: int) -> str:
        if isinstance(entry, dict) and "id" in entry:
            return str(entry["id"])
        return f"<asset {index}>"

    def _error(self, row_id: str, field: str, message: str) -> None:
        self.errors.append(f"{self._display_path()} [{row_id}] field '{field}': {message}")

    def _display_path(self) -> str:
        try:
            return self.manifest_path.relative_to(Path.cwd()).as_posix()
        except ValueError:
            return self.manifest_path.as_posix()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate asset manifest entries and required asset paths.")
    parser.add_argument(
        "--manifest",
        default=Path("assets/asset_manifest.json"),
        type=Path,
        help="Path to the asset manifest. Defaults to ./assets/asset_manifest.json.",
    )
    parser.add_argument(
        "--repo-root",
        default=Path("."),
        type=Path,
        help="Repository root used to resolve asset paths. Defaults to current directory.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    validator = AssetManifestValidator(args.manifest, args.repo_root)
    ok = validator.run()

    if ok:
        print(
            "Asset manifest validation passed: "
            f"{validator.asset_count} entries, {validator.required_count} required assets."
        )
        return 0

    print("Asset manifest validation failed:", file=sys.stderr)
    for error in validator.errors:
        print(f"- {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
