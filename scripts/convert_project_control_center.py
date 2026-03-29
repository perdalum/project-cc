#!/usr/bin/env python3

import argparse
import json
import sys
import uuid
from pathlib import Path
from typing import Optional
from urllib.parse import unquote, urlparse


ZERO_DATE = "0001-01-01T00:00:00Z"
STATE_MAP = {
    0: "New",
    2: "Active",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert ProjectControlCenter.json into Project Command And Control JSON."
    )
    parser.add_argument(
        "input",
        nargs="?",
        default="ProjectControlCenter.json",
        help="Path to the old ProjectControlCenter JSON file.",
    )
    parser.add_argument(
        "output",
        nargs="?",
        default="projects-converted.json",
        help="Path to write the converted JSON array.",
    )
    return parser.parse_args()


def normalize_date(value: Optional[str]) -> Optional[str]:
    if not value or value == ZERO_DATE:
        return None
    return value


def parse_folder_path(folder_url: Optional[str]) -> Optional[str]:
    if not folder_url:
        return None
    parsed = urlparse(folder_url)
    if parsed.scheme != "file":
        return None
    return unquote(parsed.path) or None


def deterministic_id(project: dict) -> str:
    created = project.get("createdAt") or ""
    name = project.get("name") or ""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"ProjectControlCenter:{created}:{name}"))


def convert_project(project: dict) -> dict:
    next_dates = project.get("nextDates", [])
    latest_next = normalize_date(project.get("latestNextAt"))
    if latest_next is None and next_dates:
        recorded = [
            item.get("date")
            for item in next_dates
            if normalize_date(item.get("date")) is not None
        ]
        latest_next = recorded[-1] if recorded else None

    notes = [
        {
            "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"note:{project.get('name','')}:{note.get('createdAt','')}:{note.get('text','')}")),
            "date": normalize_date(note.get("createdAt")) or project.get("createdAt") or ZERO_DATE,
            "text": note.get("text", ""),
        }
        for note in project.get("notes", [])
    ]

    touched = [
        item.get("date")
        for item in project.get("touches", [])
        if normalize_date(item.get("date")) is not None
    ]

    state = STATE_MAP.get(project.get("stateRaw"), "New")

    return {
        "id": deterministic_id(project),
        "created": normalize_date(project.get("createdAt")) or ZERO_DATE,
        "name": project.get("name", ""),
        "category": "",
        "projectType": "Classical Project",
        "state": state,
        "log": [],
        "start": None,
        "end": None,
        "modified": normalize_date(project.get("modifiedAt"))
        or normalize_date(project.get("latestTouchAt"))
        or normalize_date(project.get("createdAt"))
        or ZERO_DATE,
        "folder": parse_folder_path(project.get("folderURL")),
        "notes": notes,
        "touched": touched,
        "latestReview": normalize_date(project.get("reviewedAt")),
        "next": latest_next,
        "url": None,
        "goal": "",
    }


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return 1

    with input_path.open() as fh:
        source = json.load(fh)

    projects = source.get("projects")
    if not isinstance(projects, list):
        print("Input JSON does not contain a top-level 'projects' list.", file=sys.stderr)
        return 1

    converted = [convert_project(project) for project in projects]

    with output_path.open("w") as fh:
        json.dump(converted, fh, indent=2)
        fh.write("\n")

    print(f"Converted {len(converted)} projects to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
