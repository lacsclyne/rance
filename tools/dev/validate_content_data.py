#!/usr/bin/env python3
"""Fallback content validator for workstations without a Godot binary.

The runtime-facing loader lives in src/data/content_data_loader.gd. This script
mirrors the first-pass contract closely enough for local smoke validation in
environments where `godot --headless` is not available.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ID_RE = re.compile(r"^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$")
COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")

TABLES = [
    {
        "key": "factions",
        "file": "factions/factions.json",
        "array": "factions",
        "id_prefix": "faction.",
    },
    {
        "key": "statuses",
        "file": "statuses/statuses.json",
        "array": "statuses",
        "id_prefix": "status.",
    },
    {
        "key": "cards",
        "file": "cards/cards.json",
        "array": "cards",
        "id_prefix": "card.",
    },
    {
        "key": "skills",
        "file": "skills/skills.json",
        "array": "skills",
        "id_prefix": "skill.",
    },
    {
        "key": "characters",
        "file": "characters/characters.json",
        "array": "characters",
        "id_prefix": "character.",
    },
    {
        "key": "enemies",
        "file": "enemies/enemies.json",
        "array": "enemies",
        "id_prefix": "enemy.",
    },
    {
        "key": "reward_pools",
        "file": "reward_pools/reward_pools.json",
        "array": "reward_pools",
        "id_prefix": "reward_pool.",
    },
    {
        "key": "encounters",
        "file": "encounters/encounters.json",
        "array": "encounters",
        "id_prefix": "encounter.",
    },
    {
        "key": "progression_nodes",
        "file": "progression/progression.json",
        "array": "progression_nodes",
        "id_prefix": "progression.",
    },
    {
        "key": "quests",
        "file": "quests/quests.json",
        "array": "quests",
        "id_prefix": "quest.",
    },
    {
        "key": "campaigns",
        "file": "campaign/campaigns.json",
        "array": "campaigns",
        "id_prefix": "campaign.",
    },
]

REQUIRED_FIELDS = {
    "factions": ["id", "name", "alignment", "color"],
    "statuses": ["id", "name", "polarity", "stack_rule", "default_duration", "description"],
    "cards": ["id", "name", "type", "rarity", "cost", "target", "effects"],
    "skills": ["id", "name", "trigger", "description"],
    "characters": ["id", "name", "faction_id", "role", "base_stats", "starting_deck", "skill_ids"],
    "enemies": ["id", "name", "faction_id", "rank", "base_stats", "skill_ids"],
    "reward_pools": ["id", "name", "entries"],
    "encounters": ["id", "name", "tier", "waves", "reward_pool_id"],
    "progression_nodes": ["id", "name", "requires", "unlocks"],
    "quests": ["id", "name", "objective", "encounter_ids", "reward_pool_id"],
    "campaigns": ["id", "name", "entry_character_ids", "acts"],
}

ENUMS = {
    "alignment": ["ally", "neutral", "enemy"],
    "polarity": ["buff", "debuff"],
    "stack_rule": ["add", "replace", "intensity"],
    "card_type": ["attack", "skill", "power"],
    "rarity": ["starter", "common", "uncommon", "rare"],
    "target": ["self", "ally", "enemy", "all_enemies"],
    "effect_type": ["damage", "block", "heal", "draw", "apply_status", "gain_energy"],
    "skill_trigger": ["battle_start", "turn_start", "card_played", "on_damage", "active"],
    "enemy_rank": ["minion", "elite", "boss"],
    "reward_kind": ["card", "skill"],
    "unlock_kind": ["character", "card", "skill", "encounter", "quest"],
}

KIND_TARGETS = {
    "character": "characters",
    "card": "cards",
    "skill": "skills",
    "encounter": "encounters",
    "quest": "quests",
}

CONTENT_LABELS = {
    "factions": "faction",
    "statuses": "status",
    "cards": "card",
    "skills": "skill",
    "characters": "character",
    "enemies": "enemy",
    "reward_pools": "reward pool",
    "encounters": "encounter",
    "progression_nodes": "progression node",
    "quests": "quest",
    "campaigns": "campaign",
}


class ContentValidator:
    def __init__(self, data_root: Path) -> None:
        self.data_root = data_root
        self.files: dict[str, Path] = {}
        self.documents: dict[str, dict[str, Any]] = {}
        self.indexes: dict[str, dict[str, dict[str, Any]]] = {
            table["key"]: {} for table in TABLES
        }
        self.errors: list[str] = []
        self._all_ids: dict[str, str] = {}

    def run(self) -> bool:
        self._load_documents()
        if self.errors:
            return False

        for table in TABLES:
            self._validate_collection_shape(table)

        self._validate_references()
        return not self.errors

    def record_count(self) -> int:
        return sum(len(index) for index in self.indexes.values())

    def _load_documents(self) -> None:
        for table in TABLES:
            table_key = table["key"]
            file_path = self.data_root / table["file"]
            self.files[table_key] = file_path

            if not file_path.exists():
                self._error(file_path, "<file>", "<file>", "missing data file")
                continue

            try:
                with file_path.open("r", encoding="utf-8-sig") as handle:
                    document = json.load(handle)
            except json.JSONDecodeError as exc:
                self._error(file_path, "<json>", "<json>", f"parse error at line {exc.lineno}: {exc.msg}")
                continue
            except OSError as exc:
                self._error(file_path, "<file>", "<file>", f"could not open file: {exc}")
                continue

            if not isinstance(document, dict):
                self._error(file_path, "<file>", "<root>", "expected JSON object")
                continue

            self.documents[table_key] = document

    def _validate_collection_shape(self, table: dict[str, str]) -> None:
        table_key = table["key"]
        array_key = table["array"]
        file_path = self.files[table_key]
        document = self.documents.get(table_key)
        if document is None:
            return

        self._require_fields(document, ["version", array_key], file_path, "<file>")
        if "version" in document:
            self._validate_int_min(document["version"], file_path, "<file>", "version", 1)

        rows = document.get(array_key)
        if rows is None:
            return
        if not isinstance(rows, list):
            self._error(file_path, "<file>", array_key, "expected array")
            return

        for index, row in enumerate(rows):
            row_id = self._row_label(row, index)
            row_path = f"{array_key}[{index}]"
            if not isinstance(row, dict):
                self._error(file_path, row_id, row_path, "expected object")
                continue

            self._require_fields(row, REQUIRED_FIELDS[table_key], file_path, row_id)
            self._validate_row_id(row, table, file_path, row_id)
            self._validate_row_shape(table_key, row, file_path, self._row_label(row, index))

    def _validate_row_id(
        self,
        row: dict[str, Any],
        table: dict[str, str],
        file_path: Path,
        row_id: str,
    ) -> None:
        if "id" not in row:
            return

        value = row["id"]
        if not isinstance(value, str):
            self._error(file_path, row_id, "id", "expected string")
            return
        if not value:
            self._error(file_path, row_id, "id", "must not be empty")
            return
        if not ID_RE.fullmatch(value):
            self._error(file_path, value, "id", "must match <kind>.<name> lowercase ID format")
        if not value.startswith(table["id_prefix"]):
            self._error(file_path, value, "id", f"must start with '{table['id_prefix']}'")

        table_key = table["key"]
        if value in self.indexes[table_key]:
            self._error(file_path, value, "id", f"duplicate ID in {table['array']}")
        else:
            self.indexes[table_key][value] = row

        if value in self._all_ids:
            self._error(file_path, value, "id", f"duplicate ID also appears in {self._all_ids[value]}")
        else:
            self._all_ids[value] = self._display_path(file_path)

    def _validate_row_shape(
        self,
        table_key: str,
        row: dict[str, Any],
        file_path: Path,
        row_id: str,
    ) -> None:
        if table_key == "factions":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_enum(row, file_path, row_id, "alignment", ENUMS["alignment"])
            self._validate_regex(row, file_path, row_id, "color", COLOR_RE, "expected #RRGGBB hex color")
            self._validate_optional_string(row, file_path, row_id, "summary")
        elif table_key == "statuses":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_enum(row, file_path, row_id, "polarity", ENUMS["polarity"])
            self._validate_enum(row, file_path, row_id, "stack_rule", ENUMS["stack_rule"])
            self._validate_int_min_field(row, file_path, row_id, "default_duration", 0)
            self._validate_non_empty_string(row, file_path, row_id, "description")
        elif table_key == "cards":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_enum(row, file_path, row_id, "type", ENUMS["card_type"])
            self._validate_enum(row, file_path, row_id, "rarity", ENUMS["rarity"])
            self._validate_int_min_field(row, file_path, row_id, "cost", 0)
            self._validate_enum(row, file_path, row_id, "target", ENUMS["target"])
            self._validate_string_array(row, file_path, row_id, "tags")
            self._validate_card_effects(row, file_path, row_id)
        elif table_key == "skills":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_enum(row, file_path, row_id, "trigger", ENUMS["skill_trigger"])
            self._validate_non_empty_string(row, file_path, row_id, "description")
            self._validate_string_array(row, file_path, row_id, "status_ids")
            if "numeric_value" in row and not self._is_int(row["numeric_value"]):
                self._error(file_path, row_id, "numeric_value", "expected integer")
        elif table_key == "characters":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_non_empty_string(row, file_path, row_id, "role")
            self._validate_stats(row, file_path, row_id, "base_stats")
            self._validate_string_array(row, file_path, row_id, "starting_deck")
            self._validate_string_array(row, file_path, row_id, "skill_ids")
            self._validate_optional_string(row, file_path, row_id, "bio")
        elif table_key == "enemies":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_enum(row, file_path, row_id, "rank", ENUMS["enemy_rank"])
            self._validate_stats(row, file_path, row_id, "base_stats")
            self._validate_string_array(row, file_path, row_id, "skill_ids")
            self._validate_optional_string(row, file_path, row_id, "intent_notes")
        elif table_key == "reward_pools":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_reward_entries(row, file_path, row_id)
        elif table_key == "encounters":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_int_min_field(row, file_path, row_id, "tier", 1)
            self._validate_waves(row, file_path, row_id)
            self._validate_optional_string(row, file_path, row_id, "environment")
        elif table_key == "progression_nodes":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_string_array(row, file_path, row_id, "requires")
            self._validate_unlocks(row, file_path, row_id)
        elif table_key == "quests":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_non_empty_string(row, file_path, row_id, "objective")
            self._validate_string_array(row, file_path, row_id, "encounter_ids")
        elif table_key == "campaigns":
            self._validate_non_empty_string(row, file_path, row_id, "name")
            self._validate_optional_string(row, file_path, row_id, "summary")
            self._validate_string_array(row, file_path, row_id, "entry_character_ids")
            self._validate_acts(row, file_path, row_id)

    def _validate_card_effects(self, row: dict[str, Any], file_path: Path, row_id: str) -> None:
        effects = self._array_value(row, file_path, row_id, "effects")
        for index, effect in enumerate(effects):
            field = f"effects[{index}]"
            if not isinstance(effect, dict):
                self._error(file_path, row_id, field, "expected object")
                continue

            self._require_fields(effect, ["type"], file_path, row_id, field)
            self._validate_enum_value(effect.get("type"), file_path, row_id, f"{field}.type", ENUMS["effect_type"])
            if effect.get("type") == "apply_status":
                self._require_fields(effect, ["status_id"], file_path, row_id, field)
            if "status_id" in effect:
                self._validate_string_value(effect["status_id"], file_path, row_id, f"{field}.status_id")
            if "amount" in effect:
                self._validate_int_min(effect["amount"], file_path, row_id, f"{field}.amount", 0)
            if "duration" in effect:
                self._validate_int_min(effect["duration"], file_path, row_id, f"{field}.duration", 1)

    def _validate_stats(self, row: dict[str, Any], file_path: Path, row_id: str, field: str) -> None:
        if field not in row:
            return
        stats = row[field]
        if not isinstance(stats, dict):
            self._error(file_path, row_id, field, "expected object")
            return

        self._require_fields(stats, ["hp", "attack", "defense", "speed"], file_path, row_id, field)
        self._validate_int_min(stats.get("hp"), file_path, row_id, f"{field}.hp", 1)
        self._validate_int_min(stats.get("attack"), file_path, row_id, f"{field}.attack", 0)
        self._validate_int_min(stats.get("defense"), file_path, row_id, f"{field}.defense", 0)
        self._validate_int_min(stats.get("speed"), file_path, row_id, f"{field}.speed", 0)

    def _validate_reward_entries(self, row: dict[str, Any], file_path: Path, row_id: str) -> None:
        entries = self._array_value(row, file_path, row_id, "entries")
        for index, entry in enumerate(entries):
            field = f"entries[{index}]"
            if not isinstance(entry, dict):
                self._error(file_path, row_id, field, "expected object")
                continue

            self._require_fields(entry, ["kind", "content_id", "weight"], file_path, row_id, field)
            self._validate_enum_value(entry.get("kind"), file_path, row_id, f"{field}.kind", ENUMS["reward_kind"])
            self._validate_string_value(entry.get("content_id"), file_path, row_id, f"{field}.content_id")
            self._validate_int_min(entry.get("weight"), file_path, row_id, f"{field}.weight", 1)

    def _validate_waves(self, row: dict[str, Any], file_path: Path, row_id: str) -> None:
        waves = self._array_value(row, file_path, row_id, "waves")
        for index, wave in enumerate(waves):
            field = f"waves[{index}]"
            if not isinstance(wave, dict):
                self._error(file_path, row_id, field, "expected object")
                continue

            self._require_fields(wave, ["enemy_id", "count"], file_path, row_id, field)
            self._validate_string_value(wave.get("enemy_id"), file_path, row_id, f"{field}.enemy_id")
            self._validate_int_min(wave.get("count"), file_path, row_id, f"{field}.count", 1)

    def _validate_unlocks(self, row: dict[str, Any], file_path: Path, row_id: str) -> None:
        unlocks = self._array_value(row, file_path, row_id, "unlocks")
        for index, unlock in enumerate(unlocks):
            field = f"unlocks[{index}]"
            if not isinstance(unlock, dict):
                self._error(file_path, row_id, field, "expected object")
                continue

            self._require_fields(unlock, ["kind", "content_id"], file_path, row_id, field)
            self._validate_enum_value(unlock.get("kind"), file_path, row_id, f"{field}.kind", ENUMS["unlock_kind"])
            self._validate_string_value(unlock.get("content_id"), file_path, row_id, f"{field}.content_id")

    def _validate_acts(self, row: dict[str, Any], file_path: Path, row_id: str) -> None:
        acts = self._array_value(row, file_path, row_id, "acts")
        act_ids: set[str] = set()
        for index, act in enumerate(acts):
            field = f"acts[{index}]"
            if not isinstance(act, dict):
                self._error(file_path, row_id, field, "expected object")
                continue

            self._require_fields(act, ["id", "name", "encounter_ids", "quest_ids"], file_path, row_id, field)
            if "id" in act:
                self._validate_string_value(act["id"], file_path, row_id, f"{field}.id")
                if isinstance(act["id"], str):
                    if not ID_RE.fullmatch(act["id"]):
                        self._error(file_path, row_id, f"{field}.id", "must match <kind>.<name> lowercase ID format")
                    if not act["id"].startswith("act."):
                        self._error(file_path, row_id, f"{field}.id", "must start with 'act.'")
                    if act["id"] in act_ids:
                        self._error(file_path, row_id, f"{field}.id", f"duplicate act ID '{act['id']}'")
                    act_ids.add(act["id"])

            self._validate_non_empty_string(act, file_path, row_id, "name", field)
            self._validate_string_array(act, file_path, row_id, "encounter_ids", field)
            self._validate_string_array(act, file_path, row_id, "quest_ids", field)
            if "progression_gate_id" in act:
                self._validate_string_value(act["progression_gate_id"], file_path, row_id, f"{field}.progression_gate_id")

    def _validate_references(self) -> None:
        for row in self._rows("cards"):
            file_path = self.files["cards"]
            row_id = self._row_label(row, 0)
            for index, effect in enumerate(self._list_or_empty(row, "effects")):
                if isinstance(effect, dict) and "status_id" in effect:
                    self._validate_ref(effect["status_id"], file_path, row_id, f"effects[{index}].status_id", "statuses")

        for row in self._rows("skills"):
            self._validate_ref_array(row, self.files["skills"], self._row_label(row, 0), "status_ids", "statuses")

        for row in self._rows("characters"):
            file_path = self.files["characters"]
            row_id = self._row_label(row, 0)
            self._validate_ref_field(row, file_path, row_id, "faction_id", "factions")
            self._validate_ref_array(row, file_path, row_id, "starting_deck", "cards")
            self._validate_ref_array(row, file_path, row_id, "skill_ids", "skills")

        for row in self._rows("enemies"):
            file_path = self.files["enemies"]
            row_id = self._row_label(row, 0)
            self._validate_ref_field(row, file_path, row_id, "faction_id", "factions")
            self._validate_ref_array(row, file_path, row_id, "skill_ids", "skills")

        for row in self._rows("reward_pools"):
            file_path = self.files["reward_pools"]
            row_id = self._row_label(row, 0)
            for index, entry in enumerate(self._list_or_empty(row, "entries")):
                if not isinstance(entry, dict):
                    continue
                target = {"card": "cards", "skill": "skills"}.get(entry.get("kind"))
                if target and "content_id" in entry:
                    self._validate_ref(entry["content_id"], file_path, row_id, f"entries[{index}].content_id", target)

        for row in self._rows("encounters"):
            file_path = self.files["encounters"]
            row_id = self._row_label(row, 0)
            self._validate_ref_field(row, file_path, row_id, "reward_pool_id", "reward_pools")
            for index, wave in enumerate(self._list_or_empty(row, "waves")):
                if isinstance(wave, dict) and "enemy_id" in wave:
                    self._validate_ref(wave["enemy_id"], file_path, row_id, f"waves[{index}].enemy_id", "enemies")

        for row in self._rows("progression_nodes"):
            file_path = self.files["progression_nodes"]
            row_id = self._row_label(row, 0)
            self._validate_ref_array(row, file_path, row_id, "requires", "progression_nodes")
            for index, unlock in enumerate(self._list_or_empty(row, "unlocks")):
                if not isinstance(unlock, dict):
                    continue
                target = KIND_TARGETS.get(unlock.get("kind"))
                if target and "content_id" in unlock:
                    self._validate_ref(unlock["content_id"], file_path, row_id, f"unlocks[{index}].content_id", target)

        for row in self._rows("quests"):
            file_path = self.files["quests"]
            row_id = self._row_label(row, 0)
            self._validate_ref_array(row, file_path, row_id, "encounter_ids", "encounters")
            self._validate_ref_field(row, file_path, row_id, "reward_pool_id", "reward_pools")
            if "progression_reward_id" in row:
                self._validate_ref_field(row, file_path, row_id, "progression_reward_id", "progression_nodes")

        for row in self._rows("campaigns"):
            file_path = self.files["campaigns"]
            row_id = self._row_label(row, 0)
            self._validate_ref_array(row, file_path, row_id, "entry_character_ids", "characters")
            for index, act in enumerate(self._list_or_empty(row, "acts")):
                if not isinstance(act, dict):
                    continue
                prefix = f"acts[{index}]"
                self._validate_ref_array(act, file_path, row_id, "encounter_ids", "encounters", prefix)
                self._validate_ref_array(act, file_path, row_id, "quest_ids", "quests", prefix)
                if "progression_gate_id" in act:
                    self._validate_ref(act["progression_gate_id"], file_path, row_id, f"{prefix}.progression_gate_id", "progression_nodes")

    def _require_fields(
        self,
        target: dict[str, Any],
        fields: list[str],
        file_path: Path,
        row_id: str,
        prefix: str = "",
    ) -> None:
        for field in fields:
            if field not in target:
                self._error(file_path, row_id, self._field(prefix, field), "missing required field")

    def _validate_non_empty_string(
        self,
        target: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        prefix: str = "",
    ) -> None:
        if field not in target:
            return
        field_path = self._field(prefix, field)
        if self._validate_string_value(target[field], file_path, row_id, field_path) and not target[field].strip():
            self._error(file_path, row_id, field_path, "must not be empty")

    def _validate_optional_string(self, target: dict[str, Any], file_path: Path, row_id: str, field: str) -> None:
        if field in target:
            self._validate_string_value(target[field], file_path, row_id, field)

    def _validate_enum(
        self,
        target: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        allowed: list[str],
    ) -> None:
        if field in target:
            self._validate_enum_value(target[field], file_path, row_id, field, allowed)

    def _validate_enum_value(
        self,
        value: Any,
        file_path: Path,
        row_id: str,
        field: str,
        allowed: list[str],
    ) -> None:
        if not self._validate_string_value(value, file_path, row_id, field):
            return
        if value not in allowed:
            self._error(file_path, row_id, field, f"expected one of {allowed}, got '{value}'")

    def _validate_regex(
        self,
        target: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        pattern: re.Pattern[str],
        message: str,
    ) -> None:
        if field not in target:
            return
        if self._validate_string_value(target[field], file_path, row_id, field) and not pattern.fullmatch(target[field]):
            self._error(file_path, row_id, field, message)

    def _validate_string_array(
        self,
        target: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        prefix: str = "",
    ) -> None:
        if field not in target:
            return
        field_path = self._field(prefix, field)
        if not isinstance(target[field], list):
            self._error(file_path, row_id, field_path, "expected array")
            return
        for index, value in enumerate(target[field]):
            self._validate_string_value(value, file_path, row_id, f"{field_path}[{index}]")

    def _validate_int_min_field(
        self,
        target: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        minimum: int,
    ) -> None:
        if field in target:
            self._validate_int_min(target[field], file_path, row_id, field, minimum)

    def _validate_string_value(self, value: Any, file_path: Path, row_id: str, field: str) -> bool:
        if not isinstance(value, str):
            self._error(file_path, row_id, field, "expected string")
            return False
        if value == "":
            self._error(file_path, row_id, field, "must not be empty")
            return False
        return True

    def _validate_int_min(self, value: Any, file_path: Path, row_id: str, field: str, minimum: int) -> bool:
        if not self._is_int(value):
            self._error(file_path, row_id, field, "expected integer")
            return False
        if value < minimum:
            self._error(file_path, row_id, field, f"must be >= {minimum}")
            return False
        return True

    def _validate_ref_field(
        self,
        row: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        target_key: str,
    ) -> None:
        if field in row:
            self._validate_ref(row[field], file_path, row_id, field, target_key)

    def _validate_ref_array(
        self,
        row: dict[str, Any],
        file_path: Path,
        row_id: str,
        field: str,
        target_key: str,
        prefix: str = "",
    ) -> None:
        values = row.get(field)
        if not isinstance(values, list):
            return
        field_path = self._field(prefix, field)
        for index, value in enumerate(values):
            self._validate_ref(value, file_path, row_id, f"{field_path}[{index}]", target_key)

    def _validate_ref(self, value: Any, file_path: Path, row_id: str, field: str, target_key: str) -> None:
        if not isinstance(value, str):
            return
        if value not in self.indexes[target_key]:
            self._error(file_path, row_id, field, f"unknown {CONTENT_LABELS[target_key]} id '{value}'")

    def _array_value(self, row: dict[str, Any], file_path: Path, row_id: str, field: str) -> list[Any]:
        if field not in row:
            return []
        if not isinstance(row[field], list):
            self._error(file_path, row_id, field, "expected array")
            return []
        return row[field]

    def _rows(self, table_key: str) -> list[dict[str, Any]]:
        table = self._table(table_key)
        document = self.documents.get(table_key)
        if document is None:
            return []
        rows = document.get(table["array"])
        if not isinstance(rows, list):
            return []
        return [row for row in rows if isinstance(row, dict)]

    def _list_or_empty(self, row: dict[str, Any], field: str) -> list[Any]:
        value = row.get(field)
        return value if isinstance(value, list) else []

    def _table(self, table_key: str) -> dict[str, str]:
        for table in TABLES:
            if table["key"] == table_key:
                return table
        raise KeyError(table_key)

    def _row_label(self, row: Any, index: int) -> str:
        if isinstance(row, dict) and "id" in row:
            return str(row["id"])
        return f"<row {index}>"

    def _field(self, prefix: str, field: str) -> str:
        return f"{prefix}.{field}" if prefix else field

    def _is_int(self, value: Any) -> bool:
        return isinstance(value, int) and not isinstance(value, bool)

    def _error(self, file_path: Path, row_id: str, field: str, message: str) -> None:
        self.errors.append(f"{self._display_path(file_path)} [{row_id}] field '{field}': {message}")

    def _display_path(self, file_path: Path) -> str:
        try:
            return file_path.relative_to(Path.cwd()).as_posix()
        except ValueError:
            return file_path.as_posix()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate first-pass content JSON files.")
    parser.add_argument(
        "--data-root",
        default="data",
        type=Path,
        help="Path to the data directory. Defaults to ./data.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    validator = ContentValidator(args.data_root)
    ok = validator.run()

    if ok:
        print(
            "Content data validation passed: "
            f"{len(TABLES)} collections, {validator.record_count()} records."
        )
        return 0

    print("Content data validation failed:", file=sys.stderr)
    for error in validator.errors:
        print(f"- {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
