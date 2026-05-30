#!/usr/bin/env python3
"""Validate the local Godot desktop export path."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_PRESET = "Windows Desktop"
DEFAULT_OUTPUT = Path("build/dev/windows/rance.exe")
GODOT_CANDIDATES = (
    "godot",
    "godot4",
    "godot4.4",
    "godot4.3",
    "godot4.2",
    "Godot",
)
TEMPLATE_ERROR_MARKERS = (
    "export_templates",
    "export template",
    "export templates",
    "template file",
    "template not found",
    "template is missing",
    "not installed",
    "\u5bfc\u51fa\u6a21\u677f",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a local Godot export smoke check for the desktop preset."
    )
    parser.add_argument(
        "--godot",
        help="Path to the Godot executable. Defaults to GODOT_BIN or PATH lookup.",
    )
    parser.add_argument(
        "--project-root",
        default=Path(__file__).resolve().parents[2],
        type=Path,
        help="Godot project root. Defaults to this repository root.",
    )
    parser.add_argument(
        "--preset",
        default=DEFAULT_PRESET,
        help=f"Export preset name to validate. Defaults to '{DEFAULT_PRESET}'.",
    )
    parser.add_argument(
        "--output",
        default=DEFAULT_OUTPUT,
        type=Path,
        help=f"Export artifact path. Defaults to {DEFAULT_OUTPUT.as_posix()}.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only load the project headlessly; does not require export templates.",
    )
    return parser.parse_args()


def resolve_godot(explicit: str | None) -> str | None:
    if explicit:
        return explicit

    env_path = os.environ.get("GODOT_BIN")
    if env_path:
        return env_path

    for candidate in GODOT_CANDIDATES:
        found = shutil.which(candidate)
        if found:
            return found
    return None


def run_command(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        encoding="utf-8",
        errors="replace",
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def print_command_result(result: subprocess.CompletedProcess[str]) -> None:
    output = result.stdout.strip()
    if output:
        print(output)


def looks_like_missing_templates(output: str) -> bool:
    normalized = output.lower()
    return ("template" in normalized or "\u6a21\u677f" in normalized) and any(
        marker in normalized for marker in TEMPLATE_ERROR_MARKERS
    )


def resolve_output_path(project_root: Path, output: Path) -> Path:
    if output.is_absolute():
        return output
    return project_root / output


def copy_project_to_temp(project_root: Path, temp_parent: Path) -> Path:
    temp_project = temp_parent / "project"
    shutil.copytree(
        project_root,
        temp_project,
        ignore=shutil.ignore_patterns(
            ".git",
            ".godot",
            ".import",
            ".omx",
            "build",
            "__pycache__",
            "*.pyc",
        ),
    )
    return temp_project


def copy_export_artifacts(temp_output: Path, final_output: Path) -> None:
    final_output.parent.mkdir(parents=True, exist_ok=True)
    for artifact in temp_output.parent.iterdir():
        destination = final_output.parent / artifact.name
        if artifact.is_dir():
            shutil.copytree(artifact, destination, dirs_exist_ok=True)
        else:
            shutil.copy2(artifact, destination)


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    presets_path = project_root / "export_presets.cfg"

    godot_bin = resolve_godot(args.godot)
    if godot_bin is None:
        print(
            "Godot executable not found. Install Godot 4.x, add it to PATH, "
            "set GODOT_BIN, or pass --godot <path>.",
            file=sys.stderr,
        )
        return 2

    if not (project_root / "project.godot").is_file():
        print(f"Godot project not found: {project_root / 'project.godot'}", file=sys.stderr)
        return 1

    if not args.dry_run and not presets_path.is_file():
        print(f"Export presets not found: {presets_path}", file=sys.stderr)
        return 1

    version = run_command([godot_bin, "--version"], project_root)
    if version.returncode == 0:
        print(f"Using Godot: {version.stdout.strip()}")

    output_path = resolve_output_path(project_root, args.output)
    with tempfile.TemporaryDirectory(prefix="rance-godot-export-") as temp_dir_name:
        temp_project = copy_project_to_temp(project_root, Path(temp_dir_name))

        if args.dry_run:
            command = [godot_bin, "--headless", "--path", str(temp_project), "--quit"]
            result = run_command(command, temp_project)
            print_command_result(result)
            if result.returncode != 0:
                print("Godot project dry-run validation failed.", file=sys.stderr)
                return result.returncode
            print("Godot project dry-run validation passed.")
            return 0

        temp_output_arg = args.output
        if temp_output_arg.is_absolute():
            temp_output_arg = DEFAULT_OUTPUT.with_name(temp_output_arg.name)
        temp_output = temp_project / temp_output_arg
        temp_output.parent.mkdir(parents=True, exist_ok=True)
        command = [
            godot_bin,
            "--headless",
            "--path",
            str(temp_project),
            "--export-debug",
            args.preset,
            str(temp_output),
        ]
        result = run_command(command, temp_project)
        print_command_result(result)

        if result.returncode != 0:
            if looks_like_missing_templates(result.stdout):
                print(
                    "Godot export templates are not installed for this Godot version "
                    f"or preset '{args.preset}'. Install the matching export templates "
                    "from Godot's Export Template Manager, then rerun this script.",
                    file=sys.stderr,
                )
                return 3

            print("Godot export validation failed.", file=sys.stderr)
            print(f"Command: {' '.join(command)}", file=sys.stderr)
            return result.returncode

        if not temp_output.is_file():
            print(f"Godot reported success, but no artifact was found at {temp_output}", file=sys.stderr)
            return 1

        copy_export_artifacts(temp_output, output_path)

    print(f"Godot export validation passed: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
