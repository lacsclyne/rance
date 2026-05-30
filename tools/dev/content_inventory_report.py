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


def build_report(data_root: Path) -> dict[str, Any]:
    validator = ContentValidator(data_root)
    validation_ok = validator.run()
    rows_by_table = {table["key"]: _rows_for_table(validator.documents, table) for table in TABLES}
    placeholders = _find_placeholders(rows_by_table)
    validation_errors = _summarize_validation_errors(validator.errors)
    content_counts = _content_counts(rows_by_table)

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
    report = build_report(args.data_root)

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
