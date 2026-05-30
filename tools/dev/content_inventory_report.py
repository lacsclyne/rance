#!/usr/bin/env python3
"""Report content inventory counts and validation summary.

This developer tool reuses the fallback content validator so local inventory
reports follow the same table list, required fields, and reference checks used
by `tools/dev/validate_content_data.py`.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

from validate_content_data import CONTENT_LABELS, TABLES, ContentValidator


DEFAULT_ASSET_MANIFEST_PATH = Path("assets/asset_manifest.json")
MVP_FACTION_TARGET = 2
MVP_CHARACTERS_PER_FACTION_TARGET = 3
MVP_CARD_VERSIONS_PER_CHARACTER_TARGET = 2

CONTENT_COUNT_ORDER = [
    ("factions", "Factions"),
    ("characters", "Characters"),
    ("cards", "Card variants"),
    ("skills", "Skills"),
    ("enemies", "Enemies"),
    ("encounters", "Encounters"),
    ("quests", "Quests"),
    ("events", "Campaign events"),
    ("endings", "Endings"),
    ("reward_pools", "Reward pools"),
    ("statuses", "Statuses"),
    ("progression_nodes", "Progression nodes"),
    ("campaigns", "Campaigns"),
]

PLACEHOLDER_RE = re.compile(
    r"\b(todo|tbd|placeholder|stub|wip|lorem ipsum)\b|<[^>]+>",
    re.IGNORECASE,
)
UNKNOWN_REF_RE = re.compile(
    r"^(?P<file>.*?) \[(?P<row>[^\]]+)\] field '(?P<field>[^']+)': "
    r"unknown (?P<target>.+?) id '(?P<id>[^']+)'$"
)
MISSING_FIELD_RE = re.compile(
    r"^(?P<file>.*?) \[(?P<row>[^\]]+)\] field '(?P<field>[^']+)': "
    r"missing required field$"
)
CARD_CHARACTER_REF_FIELDS = (
    "character_id",
    "owner_character_id",
    "source_character_id",
)
CARD_CHARACTER_REF_LIST_FIELDS = (
    "character_ids",
    "owner_character_ids",
    "source_character_ids",
)
CARD_VERSION_SLOT_FIELDS = (
    "version_slot",
    "card_version",
    "variant",
    "variant_id",
    "slot",
    "version",
)
DESIGN_PACKET_FIELDS = (
    "design_packet",
    "design_packet_url",
    "design_packet_path",
    "design_doc",
    "design_doc_url",
    "design_url",
    "packet_url",
)
CHARACTER_ASSET_FIELDS = (
    "portrait_asset_id",
    "portrait_id",
    "portrait_path",
    "asset_id",
    "asset_ref",
    "asset_refs",
)
CARD_ASSET_FIELDS = (
    "card_art_asset_id",
    "art_asset_id",
    "art_id",
    "art_path",
    "asset_id",
    "asset_ref",
    "asset_refs",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Report content inventory counts and validation summary.",
    )
    parser.add_argument(
        "--data-root",
        default="data",
        type=Path,
        help="Path to the data directory. Defaults to ./data.",
    )
    parser.add_argument(
        "--asset-manifest",
        default=DEFAULT_ASSET_MANIFEST_PATH,
        type=Path,
        help=(
            "Path to the asset manifest used for roster asset coverage. "
            "Defaults to ./assets/asset_manifest.json."
        ),
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        help="Write the machine-readable JSON report to this path.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the JSON report instead of the readable console summary.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with a non-zero status when validation errors are present.",
    )
    return parser.parse_args()


def build_report(
    data_root: Path,
    asset_manifest_path: Path = DEFAULT_ASSET_MANIFEST_PATH,
) -> dict[str, Any]:
    validator = ContentValidator(data_root)
    validation_ok = validator.run()
    rows_by_table = {table["key"]: _rows_for_table(validator.documents, table) for table in TABLES}
    placeholders = _find_placeholders(rows_by_table)
    validation_errors = _summarize_validation_errors(validator.errors)
    content_counts = _content_counts(rows_by_table)
    mvp_roster_coverage = _mvp_roster_coverage(
        rows_by_table,
        asset_manifest_path,
        MVP_FACTION_TARGET,
        MVP_CHARACTERS_PER_FACTION_TARGET,
        MVP_CARD_VERSIONS_PER_CHARACTER_TARGET,
    )

    return {
        "data_root": data_root.as_posix(),
        "validation": {
            "ok": validation_ok,
            "collection_count": len(TABLES),
            "record_count": sum(content_counts.values()),
            "error_count": len(validator.errors),
            "missing_reference_count": validation_errors["missing_references"]["count"],
            "missing_required_field_count": validation_errors["missing_required_fields"]["count"],
            "placeholder_string_count": placeholders["count"],
            "errors": validator.errors,
        },
        "content_counts": content_counts,
        "collections": _collection_reports(data_root, rows_by_table),
        "summaries": _content_summaries(rows_by_table),
        "missing_references": validation_errors["missing_references"],
        "missing_required_fields": validation_errors["missing_required_fields"],
        "placeholders": placeholders,
        "mvp_roster_coverage": mvp_roster_coverage,
    }


def render_summary(report: dict[str, Any]) -> str:
    validation = report["validation"]
    summaries = report["summaries"]
    lines = [
        "Content Inventory",
        f"Data root: {report['data_root']}",
        (
            "Validation: "
            f"{'passed' if validation['ok'] else 'failed'} "
            f"({validation['error_count']} errors, "
            f"{validation['missing_reference_count']} missing references, "
            f"{validation['placeholder_string_count']} placeholder strings)"
        ),
        "",
        "Counts:",
    ]

    for key, label in CONTENT_COUNT_ORDER:
        lines.append(f"- {label}: {report['content_counts'].get(key, 0)}")

    lines.extend(
        [
            "",
            "Summaries:",
            f"- Factions by alignment: {_format_counts(summaries['factions']['by_alignment'])}",
            f"- Characters by faction: {_format_counts(summaries['characters']['by_faction_id'])}",
            f"- Card variants by type: {_format_counts(summaries['cards']['by_type'])}",
            f"- Card variants by rarity: {_format_counts(summaries['cards']['by_rarity'])}",
            f"- Skills by trigger: {_format_counts(summaries['skills']['by_trigger'])}",
            f"- Enemies by rank: {_format_counts(summaries['enemies']['by_rank'])}",
            f"- Encounters by tier: {_format_counts(summaries['encounters']['by_tier'])}",
            f"- Quests by reward pool: {_format_counts(summaries['quests']['by_reward_pool_id'])}",
            f"- Events by campaign: {_format_counts(summaries['events']['by_campaign_id'])}",
            f"- Event trigger fields: {_format_counts(summaries['events']['trigger_fields'])}",
            f"- Endings by campaign: {_format_counts(summaries['endings']['by_campaign_id'])}",
            f"- Endings by exclusive group: {_format_counts(summaries['endings']['by_exclusive_group'])}",
            f"- Reward pool entries by kind: {_format_counts(summaries['reward_pools']['entries_by_kind'])}",
        ]
    )

    lines.extend(_render_mvp_roster_coverage(report["mvp_roster_coverage"]))

    if validation["error_count"]:
        lines.append("")
        lines.append("Validation errors:")
        for error in validation["errors"][:10]:
            lines.append(f"- {error}")
        if validation["error_count"] > 10:
            lines.append(f"- ... {validation['error_count'] - 10} more")

    if report["placeholders"]["count"]:
        lines.append("")
        lines.append("Placeholder strings:")
        for example in report["placeholders"]["examples"]:
            lines.append(
                "- {collection} {row_id} {path}: {value}".format(**example)
            )

    return "\n".join(lines)


def _rows_for_table(
    documents: dict[str, dict[str, Any]],
    table: dict[str, str],
) -> list[Any]:
    document = documents.get(table["key"])
    if not isinstance(document, dict):
        return []
    rows = document.get(table["array"])
    if not isinstance(rows, list):
        return []
    return rows


def _content_counts(rows_by_table: dict[str, list[Any]]) -> dict[str, int]:
    return {key: len(rows_by_table.get(key, [])) for key, _label in CONTENT_COUNT_ORDER}


def _collection_reports(
    data_root: Path,
    rows_by_table: dict[str, list[Any]],
) -> dict[str, dict[str, Any]]:
    reports: dict[str, dict[str, Any]] = {}
    for table in TABLES:
        table_key = table["key"]
        rows = rows_by_table[table_key]
        reports[table_key] = {
            "label": CONTENT_LABELS[table_key],
            "file": (data_root / table["file"]).as_posix(),
            "array": table["array"],
            "count": len(rows),
            "ids": sorted(
                row["id"]
                for row in rows
                if isinstance(row, dict) and isinstance(row.get("id"), str)
            ),
        }
    return reports


def _content_summaries(rows_by_table: dict[str, list[Any]]) -> dict[str, Any]:
    return {
        "factions": _faction_summary(_dict_rows(rows_by_table["factions"])),
        "statuses": _status_summary(_dict_rows(rows_by_table["statuses"])),
        "cards": _card_summary(_dict_rows(rows_by_table["cards"])),
        "skills": _skill_summary(_dict_rows(rows_by_table["skills"])),
        "characters": _character_summary(_dict_rows(rows_by_table["characters"])),
        "enemies": _enemy_summary(_dict_rows(rows_by_table["enemies"])),
        "reward_pools": _reward_pool_summary(_dict_rows(rows_by_table["reward_pools"])),
        "encounters": _encounter_summary(_dict_rows(rows_by_table["encounters"])),
        "progression_nodes": _progression_summary(_dict_rows(rows_by_table["progression_nodes"])),
        "quests": _quest_summary(_dict_rows(rows_by_table["quests"])),
        "campaigns": _campaign_summary(_dict_rows(rows_by_table["campaigns"])),
        "events": _event_summary(_dict_rows(rows_by_table["events"])),
        "endings": _ending_summary(_dict_rows(rows_by_table["endings"])),
    }


def _mvp_roster_coverage(
    rows_by_table: dict[str, list[Any]],
    asset_manifest_path: Path,
    faction_target: int,
    character_target: int,
    card_version_target: int,
) -> dict[str, Any]:
    factions = _dict_rows(rows_by_table["factions"])
    characters = _dict_rows(rows_by_table["characters"])
    cards = _dict_rows(rows_by_table["cards"])
    asset_manifest = _asset_manifest_report(asset_manifest_path)
    characters_by_faction = _characters_by_faction(characters)
    roster_factions = _select_roster_factions(factions, characters_by_faction, faction_target)
    roster_faction_ids = {faction["id"] for faction in roster_factions if isinstance(faction.get("id"), str)}
    non_roster_factions = [
        _faction_reference(faction, len(characters_by_faction.get(str(faction.get("id")), [])))
        for faction in factions
        if isinstance(faction.get("id"), str) and faction["id"] not in roster_faction_ids
    ]
    card_model = _card_version_model(cards)
    design_model = {
        "character_fields": _observed_fields(characters, DESIGN_PACKET_FIELDS),
        "card_fields": _observed_fields(cards, DESIGN_PACKET_FIELDS),
    }
    asset_model = {
        "character_fields": _observed_fields(characters, CHARACTER_ASSET_FIELDS),
        "card_fields": _observed_fields(cards, CARD_ASSET_FIELDS),
        "manifest_path": asset_manifest["path"],
        "manifest_present": asset_manifest["present"],
        "manifest_errors": asset_manifest["errors"],
    }

    faction_reports: list[dict[str, Any]] = []
    missing_character_slots = 0
    missing_card_version_slots = 0
    duplicate_version_slot_count = 0
    missing_design_packet_link_count = 0
    missing_asset_reference_count = 0

    for faction in roster_factions:
        faction_id = str(faction["id"])
        faction_characters = characters_by_faction.get(faction_id, [])
        character_reports: list[dict[str, Any]] = []
        faction_missing_character_slots = max(0, character_target - len(faction_characters))
        missing_character_slots += faction_missing_character_slots

        for character in faction_characters:
            character_report = _character_roster_report(
                character,
                card_model,
                asset_manifest,
                design_model["character_fields"],
                design_model["card_fields"],
                asset_model["character_fields"],
                asset_model["card_fields"],
                card_version_target,
            )
            character_reports.append(character_report)
            card_versions = character_report["card_versions"]
            missing_card_version_slots += card_versions["missing_version_slots"]
            duplicate_version_slot_count += len(card_versions["duplicate_version_slots"])
            missing_design_packet_link_count += character_report["missing_design_packet_link_count"]
            missing_asset_reference_count += character_report["missing_asset_reference_count"]

        faction_reports.append(
            {
                "id": faction_id,
                "name": faction.get("name", faction_id),
                "alignment": faction.get("alignment"),
                "character_count": len(faction_characters),
                "character_target": character_target,
                "missing_character_slots": faction_missing_character_slots,
                "characters": character_reports,
            }
        )

    missing_faction_slots = max(0, faction_target - len(roster_factions))
    issue_count = (
        missing_faction_slots
        + missing_character_slots
        + missing_card_version_slots
        + duplicate_version_slot_count
        + missing_design_packet_link_count
        + missing_asset_reference_count
    )

    return {
        "advisory": True,
        "targets": {
            "factions": faction_target,
            "characters_per_faction": character_target,
            "card_versions_per_character": card_version_target,
        },
        "status": "complete" if issue_count == 0 else "incomplete",
        "summary": {
            "roster_faction_count": len(roster_factions),
            "missing_faction_slots": missing_faction_slots,
            "extra_roster_faction_count": max(0, len(roster_factions) - faction_target),
            "missing_character_slots": missing_character_slots,
            "missing_card_version_slots": missing_card_version_slots,
            "duplicate_version_slot_count": duplicate_version_slot_count,
            "missing_design_packet_link_count": missing_design_packet_link_count,
            "missing_asset_reference_count": missing_asset_reference_count,
        },
        "factions": faction_reports,
        "non_roster_factions": non_roster_factions,
        "card_version_model": {
            "available": card_model["available"],
            "character_ref_fields": card_model["character_ref_fields"],
            "version_slot_fields": card_model["version_slot_fields"],
            "note": card_model["note"],
        },
        "design_packet_model": {
            "available": bool(design_model["character_fields"] or design_model["card_fields"]),
            "character_fields": design_model["character_fields"],
            "card_fields": design_model["card_fields"],
        },
        "asset_reference_model": asset_model,
    }


def _render_mvp_roster_coverage(roster: dict[str, Any]) -> list[str]:
    targets = roster["targets"]
    summary = roster["summary"]
    lines = [
        "",
        "MVP Roster Coverage (advisory):",
        (
            "Target: "
            f"{targets['factions']} factions, "
            f"{targets['characters_per_faction']} characters per faction, "
            f"{targets['card_versions_per_character']} card versions per character"
        ),
        f"Coverage: {roster['status']} ({_format_roster_issues(summary)})",
        (
            "Roster factions: "
            f"{summary['roster_faction_count']}/{targets['factions']}"
        ),
    ]

    if summary["missing_faction_slots"]:
        lines.append(f"Missing faction slots: {summary['missing_faction_slots']}")
    if roster["non_roster_factions"]:
        lines.append(
            "Non-roster factions: "
            + ", ".join(
                (
                    f"{faction['id']}"
                    f" ({faction['alignment'] or 'unknown'}, "
                    f"{faction['character_count']} characters)"
                )
                for faction in roster["non_roster_factions"]
            )
        )

    for faction in roster["factions"]:
        lines.append(
            (
                f"- {faction['name']} ({faction['id']}): "
                f"{faction['character_count']}/{faction['character_target']} characters"
            )
        )
        if faction["missing_character_slots"]:
            lines.append(f"  Missing character slots: {faction['missing_character_slots']}")

        for character in faction["characters"]:
            card_versions = character["card_versions"]
            if card_versions["model_available"]:
                card_summary = (
                    f"card versions {card_versions['version_slot_count']}/"
                    f"{card_versions['target']}"
                )
            else:
                card_summary = (
                    f"card versions 0/{card_versions['target']} modeled; "
                    f"deck refs {len(card_versions['fallback_starting_deck_ids'])} unique"
                )
            lines.append(
                (
                    f"  - {character['name']} ({character['id']}): "
                    f"{card_summary}; "
                    f"portrait asset {_asset_status_label(character['portrait_asset'])}; "
                    f"design packet {_field_status_label(character['design_packet'])}"
                )
            )
            if card_versions["missing_version_slots"]:
                lines.append(
                    f"    Missing card version slots: {card_versions['missing_version_slots']}"
                )
            for duplicate in card_versions["duplicate_version_slots"]:
                lines.append(
                    (
                        f"    Duplicate version slot {duplicate['slot']}: "
                        f"{', '.join(duplicate['card_ids'])}"
                    )
                )
            if card_versions["cards_missing_version_slot"]:
                lines.append(
                    (
                        "    Cards missing version slot fields: "
                        + ", ".join(card_versions["cards_missing_version_slot"])
                    )
                )
            if card_versions["missing_card_art_source_ids"]:
                lines.append(
                    (
                        "    Missing card art manifest entries: "
                        + ", ".join(card_versions["missing_card_art_source_ids"])
                    )
                )
            if character["missing_content_asset_fields"]:
                lines.append(
                    (
                        "    Missing content asset fields: "
                        + ", ".join(character["missing_content_asset_fields"])
                    )
                )
            if card_versions["missing_card_asset_fields"]:
                lines.append(
                    (
                        "    Cards missing content asset fields: "
                        + ", ".join(card_versions["missing_card_asset_fields"])
                    )
                )

    card_model = roster["card_version_model"]
    lines.append(f"Card version model: {card_model['note']}")

    design_model = roster["design_packet_model"]
    if design_model["available"]:
        lines.append(
            (
                "Design packet fields: "
                f"characters={_format_list(design_model['character_fields'])}; "
                f"cards={_format_list(design_model['card_fields'])}"
            )
        )
    else:
        lines.append("Design packet links: no design packet fields found; skipped")

    asset_model = roster["asset_reference_model"]
    if asset_model["character_fields"] or asset_model["card_fields"]:
        lines.append(
            (
                "Content asset fields: "
                f"characters={_format_list(asset_model['character_fields'])}; "
                f"cards={_format_list(asset_model['card_fields'])}"
            )
        )
    else:
        lines.append(
            (
                "Content asset fields: none found; using asset manifest "
                f"{asset_model['manifest_path']} source_id coverage"
            )
        )
    if asset_model["manifest_errors"]:
        lines.append(
            "Asset manifest notes: " + "; ".join(asset_model["manifest_errors"])
        )

    return lines


def _faction_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "by_alignment": _count_field(rows, "alignment"),
        "ids": _ids(rows),
    }


def _status_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "by_polarity": _count_field(rows, "polarity"),
        "by_effect_type": _count_field(rows, "effect_type"),
        "by_stack_rule": _count_field(rows, "stack_rule"),
    }


def _card_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    effect_counter: Counter[str] = Counter()
    status_ref_count = 0
    for row in rows:
        for effect in _list(row.get("effects")):
            if not isinstance(effect, dict):
                continue
            if isinstance(effect.get("type"), str):
                effect_counter[effect["type"]] += 1
            if isinstance(effect.get("status_id"), str):
                status_ref_count += 1

    return {
        "by_type": _count_field(rows, "type"),
        "by_rarity": _count_field(rows, "rarity"),
        "by_target": _count_field(rows, "target"),
        "by_tag": _count_list_field(rows, "tags"),
        "effects_by_type": _counter_to_dict(effect_counter),
        "status_reference_count": status_ref_count,
    }


def _skill_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "by_trigger": _count_field(rows, "trigger"),
        "status_reference_count": sum(len(_list(row.get("status_ids"))) for row in rows),
    }


def _character_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "by_faction_id": _count_field(rows, "faction_id"),
        "by_role": _count_field(rows, "role"),
        "starting_deck_card_count": sum(len(_list(row.get("starting_deck"))) for row in rows),
        "skill_reference_count": sum(len(_list(row.get("skill_ids"))) for row in rows),
    }


def _enemy_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "by_faction_id": _count_field(rows, "faction_id"),
        "by_rank": _count_field(rows, "rank"),
        "skill_reference_count": sum(len(_list(row.get("skill_ids"))) for row in rows),
    }


def _reward_pool_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    entry_counter: Counter[str] = Counter()
    total_entries = 0
    total_weight = 0

    for row in rows:
        for entry in _list(row.get("entries")):
            if not isinstance(entry, dict):
                continue
            total_entries += 1
            if isinstance(entry.get("kind"), str):
                entry_counter[entry["kind"]] += 1
            if isinstance(entry.get("weight"), int) and not isinstance(entry["weight"], bool):
                total_weight += entry["weight"]

    return {
        "entry_count": total_entries,
        "entries_by_kind": _counter_to_dict(entry_counter),
        "total_weight": total_weight,
    }


def _encounter_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    pattern_counter: Counter[str] = Counter()
    wave_entry_count = 0
    enemy_unit_count = 0
    intent_token_count = 0

    for row in rows:
        for wave in _list(row.get("waves")):
            if not isinstance(wave, dict):
                continue
            wave_entry_count += 1
            if isinstance(wave.get("count"), int) and not isinstance(wave["count"], bool):
                enemy_unit_count += wave["count"]

        pattern = row.get("intent_pattern")
        if isinstance(pattern, dict):
            for key in ("rotation", "conditional", "key_turns"):
                if key in pattern:
                    pattern_counter[key] += 1
            intent_token_count += _count_intent_tokens(pattern)

    return {
        "by_tier": _count_field(rows, "tier"),
        "wave_entry_count": wave_entry_count,
        "enemy_unit_count": enemy_unit_count,
        "intent_patterns": _counter_to_dict(pattern_counter),
        "intent_token_count": intent_token_count,
        "by_reward_pool_id": _count_field(rows, "reward_pool_id"),
    }


def _progression_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    unlock_counter: Counter[str] = Counter()
    unlock_count = 0

    for row in rows:
        for unlock in _list(row.get("unlocks")):
            if not isinstance(unlock, dict):
                continue
            unlock_count += 1
            if isinstance(unlock.get("kind"), str):
                unlock_counter[unlock["kind"]] += 1

    return {
        "requires_count": sum(len(_list(row.get("requires"))) for row in rows),
        "unlock_count": unlock_count,
        "unlocks_by_kind": _counter_to_dict(unlock_counter),
    }


def _quest_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "encounter_reference_count": sum(len(_list(row.get("encounter_ids"))) for row in rows),
        "by_reward_pool_id": _count_field(rows, "reward_pool_id"),
        "progression_reward_count": sum(1 for row in rows if isinstance(row.get("progression_reward_id"), str)),
    }


def _event_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    trigger_counter: Counter[str] = Counter()
    effect_counter: Counter[str] = Counter()

    for row in rows:
        trigger = row.get("trigger")
        if isinstance(trigger, dict):
            for key in trigger.keys():
                trigger_counter[str(key)] += 1
        effects = row.get("effects")
        if isinstance(effects, dict):
            for key in effects.keys():
                effect_counter[str(key)] += 1

    return {
        "by_campaign_id": _count_field(rows, "campaign_id"),
        "trigger_fields": _counter_to_dict(trigger_counter),
        "effect_fields": _counter_to_dict(effect_counter),
    }


def _ending_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    priorities = [row["priority"] for row in rows if isinstance(row.get("priority"), int) and not isinstance(row["priority"], bool)]

    return {
        "by_campaign_id": _count_field(rows, "campaign_id"),
        "by_exclusive_group": _count_field(rows, "exclusive_group"),
        "priority_min": min(priorities) if priorities else None,
        "priority_max": max(priorities) if priorities else None,
        "related_faction_reference_count": sum(len(_list(row.get("related_faction_ids"))) for row in rows),
        "related_character_reference_count": sum(len(_list(row.get("related_character_ids"))) for row in rows),
        "carryover_progression_reference_count": sum(
            len(_list(row.get("discovery", {}).get("carryover_progression_ids")))
            for row in rows
            if isinstance(row.get("discovery"), dict)
        ),
    }


def _campaign_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    act_count = 0
    act_encounter_refs = 0
    act_quest_refs = 0
    progression_gate_count = 0

    for row in rows:
        for act in _list(row.get("acts")):
            if not isinstance(act, dict):
                continue
            act_count += 1
            act_encounter_refs += len(_list(act.get("encounter_ids")))
            act_quest_refs += len(_list(act.get("quest_ids")))
            if isinstance(act.get("progression_gate_id"), str):
                progression_gate_count += 1

    return {
        "entry_character_reference_count": sum(len(_list(row.get("entry_character_ids"))) for row in rows),
        "act_count": act_count,
        "act_encounter_reference_count": act_encounter_refs,
        "act_quest_reference_count": act_quest_refs,
        "progression_gate_count": progression_gate_count,
    }


def _characters_by_faction(characters: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    groups: dict[str, list[dict[str, Any]]] = {}
    for character in characters:
        faction_id = character.get("faction_id")
        if isinstance(faction_id, str):
            groups.setdefault(faction_id, []).append(character)
    return groups


def _select_roster_factions(
    factions: list[dict[str, Any]],
    characters_by_faction: dict[str, list[dict[str, Any]]],
    faction_target: int,
) -> list[dict[str, Any]]:
    roster_factions = [
        faction
        for faction in factions
        if isinstance(faction.get("id"), str) and faction.get("alignment") != "enemy"
    ]
    selected_ids = {faction["id"] for faction in roster_factions}

    if len(roster_factions) < faction_target:
        for faction in factions:
            faction_id = faction.get("id")
            if not isinstance(faction_id, str):
                continue
            if faction_id in selected_ids or faction_id not in characters_by_faction:
                continue
            roster_factions.append(faction)
            selected_ids.add(faction_id)
            if len(roster_factions) >= faction_target:
                break

    if not roster_factions:
        return [faction for faction in factions[:faction_target] if isinstance(faction.get("id"), str)]

    return roster_factions


def _faction_reference(faction: dict[str, Any], character_count: int) -> dict[str, Any]:
    faction_id = str(faction.get("id", "<missing faction id>"))
    return {
        "id": faction_id,
        "name": faction.get("name", faction_id),
        "alignment": faction.get("alignment"),
        "character_count": character_count,
    }


def _character_roster_report(
    character: dict[str, Any],
    card_model: dict[str, Any],
    asset_manifest: dict[str, Any],
    character_design_fields: list[str],
    card_design_fields: list[str],
    character_asset_fields: list[str],
    card_asset_fields: list[str],
    card_version_target: int,
) -> dict[str, Any]:
    character_id = str(character.get("id", "<missing character id>"))
    portrait_asset = _source_asset_status(asset_manifest, character_id, ["portrait"])
    design_packet = _field_coverage(character, character_design_fields)
    content_asset = _field_coverage(character, character_asset_fields)
    card_versions = _character_card_versions(
        character,
        card_model,
        asset_manifest,
        card_design_fields,
        card_asset_fields,
        card_version_target,
    )

    missing_design_count = 1 if design_packet["status"] == "missing" else 0
    missing_design_count += card_versions["missing_design_packet_link_count"]
    missing_asset_count = 1 if portrait_asset["status"] == "missing" else 0
    missing_asset_count += 1 if content_asset["status"] == "missing" else 0
    missing_asset_count += card_versions["missing_asset_reference_count"]

    return {
        "id": character_id,
        "name": character.get("name", character_id),
        "role": character.get("role"),
        "portrait_asset": portrait_asset,
        "design_packet": design_packet,
        "content_asset": content_asset,
        "card_versions": card_versions,
        "missing_design_packet_link_count": missing_design_count,
        "missing_asset_reference_count": missing_asset_count,
        "missing_content_asset_fields": (
            list(character_asset_fields) if content_asset["status"] == "missing" else []
        ),
    }


def _character_card_versions(
    character: dict[str, Any],
    card_model: dict[str, Any],
    asset_manifest: dict[str, Any],
    card_design_fields: list[str],
    card_asset_fields: list[str],
    card_version_target: int,
) -> dict[str, Any]:
    character_id = str(character.get("id", ""))
    bound_cards = card_model["cards_by_character"].get(character_id, [])
    card_index = card_model["card_index"]
    fallback_starting_deck_ids = _unique_strings(_list(character.get("starting_deck")))
    version_slots: list[str] = []
    cards_missing_version_slot: list[str] = []
    duplicate_version_slots: list[dict[str, Any]] = []
    missing_design_packet_link_count = 0
    missing_asset_reference_count = 0
    missing_card_art_source_ids: list[str] = []
    missing_card_asset_fields: list[str] = []
    missing_card_design_packet_links: list[str] = []
    slot_to_card_ids: dict[str, list[str]] = {}

    report_cards = bound_cards if bound_cards else [
        card_index[card_id]
        for card_id in fallback_starting_deck_ids
        if card_id in card_index
    ]

    for card in bound_cards:
        card_id = str(card.get("id", "<missing card id>"))
        slot = _card_version_slot(card)
        if slot is None:
            cards_missing_version_slot.append(card_id)
            continue
        version_slots.append(slot)
        slot_to_card_ids.setdefault(slot, []).append(card_id)

    for slot, card_ids in sorted(slot_to_card_ids.items()):
        if len(card_ids) > 1:
            duplicate_version_slots.append({"slot": slot, "card_ids": card_ids})

    for card in report_cards:
        card_id = str(card.get("id", "<missing card id>"))
        card_art = _source_asset_status(asset_manifest, card_id, ["card_art"])
        if card_art["status"] == "missing":
            missing_asset_reference_count += 1
            missing_card_art_source_ids.append(card_id)

        card_asset = _field_coverage(card, card_asset_fields)
        if card_asset["status"] == "missing":
            missing_asset_reference_count += 1
            missing_card_asset_fields.append(card_id)

        card_design = _field_coverage(card, card_design_fields)
        if card_design["status"] == "missing":
            missing_design_packet_link_count += 1
            missing_card_design_packet_links.append(card_id)

    version_slot_count = len(set(version_slots))
    model_available = bool(bound_cards)
    missing_version_slots = max(0, card_version_target - version_slot_count)
    if not model_available:
        missing_version_slots = card_version_target

    return {
        "target": card_version_target,
        "model_available": model_available,
        "bound_card_ids": _ids(bound_cards),
        "fallback_starting_deck_ids": fallback_starting_deck_ids,
        "version_slot_count": version_slot_count,
        "version_slots": sorted(set(version_slots)),
        "missing_version_slots": missing_version_slots,
        "duplicate_version_slots": duplicate_version_slots,
        "cards_missing_version_slot": cards_missing_version_slot,
        "missing_card_art_source_ids": missing_card_art_source_ids,
        "missing_card_asset_fields": missing_card_asset_fields,
        "missing_card_design_packet_links": missing_card_design_packet_links,
        "missing_design_packet_link_count": missing_design_packet_link_count,
        "missing_asset_reference_count": missing_asset_reference_count,
    }


def _card_version_model(cards: list[dict[str, Any]]) -> dict[str, Any]:
    cards_by_character: dict[str, list[dict[str, Any]]] = {}
    character_ref_fields: set[str] = set()
    version_slot_fields = _observed_fields(cards, CARD_VERSION_SLOT_FIELDS)
    card_index = {
        card["id"]: card
        for card in cards
        if isinstance(card.get("id"), str)
    }

    for card in cards:
        for field in CARD_CHARACTER_REF_FIELDS + CARD_CHARACTER_REF_LIST_FIELDS:
            if field in card:
                character_ref_fields.add(field)

        for character_id in _card_character_ids(card):
            cards_by_character.setdefault(character_id, []).append(card)

    if cards_by_character and version_slot_fields:
        note = (
            "character-bound cards and version slot fields found; duplicate "
            "slots are checked per character"
        )
    elif cards_by_character:
        note = (
            "character-bound cards found, but no card version slot fields were "
            "found"
        )
    else:
        note = (
            "no card character/version fields found; starting_deck refs are "
            "shown as fallback only"
        )

    return {
        "available": bool(cards_by_character),
        "cards_by_character": cards_by_character,
        "card_index": card_index,
        "character_ref_fields": sorted(character_ref_fields),
        "version_slot_fields": version_slot_fields,
        "note": note,
    }


def _card_character_ids(card: dict[str, Any]) -> list[str]:
    character_ids: list[str] = []

    for field in CARD_CHARACTER_REF_FIELDS:
        value = card.get(field)
        if isinstance(value, str):
            character_ids.append(value)

    for field in CARD_CHARACTER_REF_LIST_FIELDS:
        for value in _list(card.get(field)):
            if isinstance(value, str):
                character_ids.append(value)

    return _unique_strings(character_ids)


def _card_version_slot(card: dict[str, Any]) -> str | None:
    for field in CARD_VERSION_SLOT_FIELDS:
        value = card.get(field)
        if _has_field_value(value):
            return str(value)
    return None


def _asset_manifest_report(asset_manifest_path: Path) -> dict[str, Any]:
    report: dict[str, Any] = {
        "path": asset_manifest_path.as_posix(),
        "present": False,
        "entry_count": 0,
        "errors": [],
        "sources": {},
    }

    if not asset_manifest_path.exists():
        report["errors"].append("asset manifest not found; asset coverage skipped")
        return report

    try:
        with asset_manifest_path.open("r", encoding="utf-8-sig") as handle:
            document = json.load(handle)
    except (json.JSONDecodeError, OSError) as exc:
        report["errors"].append(f"asset manifest could not be read: {exc}")
        return report

    if not isinstance(document, dict):
        report["errors"].append("asset manifest root is not an object")
        return report

    assets = document.get("assets")
    if not isinstance(assets, list):
        report["errors"].append("asset manifest has no assets array")
        return report

    report["present"] = True
    report["entry_count"] = len(assets)
    sources: dict[str, list[dict[str, Any]]] = {}
    for entry in assets:
        if not isinstance(entry, dict):
            continue
        source_id = entry.get("source_id")
        if not isinstance(source_id, str):
            continue
        sources.setdefault(source_id, []).append(
            {
                "id": entry.get("id"),
                "category": entry.get("category"),
                "path": entry.get("path"),
                "required": entry.get("required"),
                "status": entry.get("status"),
            }
        )
    report["sources"] = sources
    return report


def _source_asset_status(
    asset_manifest: dict[str, Any],
    source_id: str,
    categories: list[str],
) -> dict[str, Any]:
    if not asset_manifest["present"]:
        return {
            "status": "skipped",
            "source_id": source_id,
            "categories": categories,
            "entries": [],
        }

    entries = [
        entry
        for entry in asset_manifest["sources"].get(source_id, [])
        if entry.get("category") in categories
    ]
    return {
        "status": "present" if entries else "missing",
        "source_id": source_id,
        "categories": categories,
        "entries": entries,
    }


def _field_coverage(row: dict[str, Any], fields: list[str]) -> dict[str, Any]:
    if not fields:
        return {"status": "not_configured", "fields": [], "field": None}

    for field in fields:
        if _has_field_value(row.get(field)):
            return {"status": "present", "fields": fields, "field": field}

    return {"status": "missing", "fields": fields, "field": None}


def _observed_fields(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[str]:
    observed = {
        field
        for row in rows
        for field in fields
        if field in row
    }
    return sorted(observed)


def _has_field_value(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list) or isinstance(value, dict):
        return bool(value)
    return True


def _unique_strings(values: list[Any]) -> list[str]:
    seen: set[str] = set()
    unique_values: list[str] = []
    for value in values:
        if not isinstance(value, str) or value in seen:
            continue
        seen.add(value)
        unique_values.append(value)
    return unique_values


def _format_roster_issues(summary: dict[str, int]) -> str:
    issues = []
    for key, label in (
        ("missing_faction_slots", "missing faction slot"),
        ("missing_character_slots", "missing character slot"),
        ("missing_card_version_slots", "missing card version slot"),
        ("duplicate_version_slot_count", "duplicate version slot"),
        ("missing_design_packet_link_count", "missing design packet link"),
        ("missing_asset_reference_count", "missing asset reference"),
    ):
        count = summary[key]
        if count:
            issues.append(_pluralize(count, label))
    return ", ".join(issues) if issues else "no roster gaps found"


def _asset_status_label(asset_status: dict[str, Any]) -> str:
    if asset_status["status"] == "present":
        return "ok"
    if asset_status["status"] == "missing":
        return "missing"
    return "skipped"


def _field_status_label(field_status: dict[str, Any]) -> str:
    if field_status["status"] == "present":
        return "ok"
    if field_status["status"] == "missing":
        return "missing"
    return "n/a"


def _format_list(values: list[str]) -> str:
    return ", ".join(values) if values else "none"


def _pluralize(count: int, singular: str) -> str:
    suffix = "" if count == 1 else "s"
    return f"{count} {singular}{suffix}"


def _summarize_validation_errors(errors: list[str]) -> dict[str, Any]:
    missing_references: list[dict[str, str]] = []
    missing_fields: list[dict[str, str]] = []

    for error in errors:
        ref_match = UNKNOWN_REF_RE.match(error)
        if ref_match:
            missing_references.append(ref_match.groupdict())
            continue

        field_match = MISSING_FIELD_RE.match(error)
        if field_match:
            missing_fields.append(field_match.groupdict())

    return {
        "missing_references": {
            "count": len(missing_references),
            "by_target": _counter_to_dict(Counter(item["target"] for item in missing_references)),
            "examples": missing_references[:10],
        },
        "missing_required_fields": {
            "count": len(missing_fields),
            "by_field": _counter_to_dict(Counter(item["field"] for item in missing_fields)),
            "examples": missing_fields[:10],
        },
    }


def _find_placeholders(rows_by_table: dict[str, list[Any]]) -> dict[str, Any]:
    examples: list[dict[str, str]] = []
    by_collection: Counter[str] = Counter()

    for table_key, rows in rows_by_table.items():
        for row_index, row in enumerate(rows):
            row_id = _row_id(row, row_index)
            for path, value in _walk_strings(row):
                if PLACEHOLDER_RE.search(value):
                    by_collection[table_key] += 1
                    if len(examples) < 10:
                        examples.append(
                            {
                                "collection": table_key,
                                "row_id": row_id,
                                "path": path,
                                "value": value,
                            }
                        )

    return {
        "count": sum(by_collection.values()),
        "by_collection": _counter_to_dict(by_collection),
        "examples": examples,
    }


def _walk_strings(value: Any, prefix: str = "") -> Iterable[tuple[str, str]]:
    if isinstance(value, str):
        yield prefix or "<value>", value
    elif isinstance(value, dict):
        for key, child in value.items():
            child_prefix = f"{prefix}.{key}" if prefix else str(key)
            yield from _walk_strings(child, child_prefix)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            child_prefix = f"{prefix}[{index}]" if prefix else f"[{index}]"
            yield from _walk_strings(child, child_prefix)


def _count_intent_tokens(value: Any) -> int:
    if isinstance(value, dict):
        count = 1 if isinstance(value.get("id"), str) and value["id"].startswith("intent.") else 0
        return count + sum(_count_intent_tokens(child) for child in value.values())
    if isinstance(value, list):
        return sum(_count_intent_tokens(child) for child in value)
    return 0


def _count_field(rows: list[dict[str, Any]], field: str) -> dict[str, int]:
    return _counter_to_dict(Counter(str(row[field]) for row in rows if field in row))


def _count_list_field(rows: list[dict[str, Any]], field: str) -> dict[str, int]:
    counter: Counter[str] = Counter()
    for row in rows:
        for value in _list(row.get(field)):
            if isinstance(value, str):
                counter[value] += 1
    return _counter_to_dict(counter)


def _counter_to_dict(counter: Counter[str]) -> dict[str, int]:
    return {key: counter[key] for key in sorted(counter)}


def _dict_rows(rows: list[Any]) -> list[dict[str, Any]]:
    return [row for row in rows if isinstance(row, dict)]


def _ids(rows: list[dict[str, Any]]) -> list[str]:
    return sorted(row["id"] for row in rows if isinstance(row.get("id"), str))


def _row_id(row: Any, index: int) -> str:
    if isinstance(row, dict) and isinstance(row.get("id"), str):
        return row["id"]
    return f"<row {index}>"


def _list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _format_counts(counts: dict[str, int]) -> str:
    if not counts:
        return "none"
    return ", ".join(f"{key}={value}" for key, value in counts.items())


def write_json(report: dict[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


def main() -> int:
    args = parse_args()
    report = build_report(args.data_root, args.asset_manifest)

    if args.json_output is not None:
        write_json(report, args.json_output)

    if args.json:
        json.dump(report, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        print(render_summary(report))
        if args.json_output is not None:
            print(f"\nJSON written to {args.json_output.as_posix()}")

    if args.strict and not report["validation"]["ok"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
