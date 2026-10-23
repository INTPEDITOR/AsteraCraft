"""Connect existing art only; root runs this after the remaining drafts are packed.

No image decoding, visual review, runtime tests, or acceptance promotion occurs.
The 21 accepted definitions and their recorded validation remain unchanged.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data/art_staged16_units.json"
STATE = ROOT / "docs/art-work-state.json"
REGISTRY = ROOT / "build/staged16_20261023/units.json"
EXPECTED = {f"{race}:{kind}" for race, count in [(0, 16), (1, 14), (2, 14)] for kind in range(count)}
ACCEPTED = {f"0:{kind}" for kind in range(16)} | {f"1:{kind}" for kind in range(5)}
PROVENANCE = {
    "day": "2026-10-24",
    "user_requested_skip_QA": True,
    "instruction": "Connect all existing unit sprites and build without additional review.",
    "qa_performed": False,
    "status": "applied_unreviewed",
}


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def ordered(keys):
    return sorted(keys, key=lambda key: tuple(map(int, key.split(":"))))


def file_refs(value):
    if isinstance(value, dict):
        if isinstance(value.get("file"), str):
            yield value["file"]
        for child in value.values():
            yield from file_refs(child)
    elif isinstance(value, list):
        for child in value:
            yield from file_refs(child)


def atomic_json(path: Path, value):
    temporary = path.with_name(path.name + ".connect-tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="List connection checks without writing anything")
    args = parser.parse_args()
    manifest, state, registry = read(MANIFEST), read(STATE), read(REGISTRY)
    before = manifest.get("units", {})
    accepted = {key: value for key, value in before.items() if value.get("status") == "accepted"}
    if set(accepted) != ACCEPTED:
        raise ValueError("Expected exactly the existing 21 accepted units; refusing to replace or reclassify them")
    accepted_list = copy.deepcopy(state.get("accepted_units", []))
    if len(accepted_list) != 21 or set(accepted_list) != ACCEPTED:
        raise ValueError("State accepted_units must contain the same 21 accepted units")
    registry_keys = [f"{row['race']}:{row['id']}" for row in registry]
    if len(registry_keys) != 44 or set(registry_keys) != EXPECTED:
        raise ValueError("Unit registry must contain exactly the 44 canonical unit keys")
    if set(before) - EXPECTED:
        raise ValueError("Manifest contains unexpected unit keys")
    drafts = {race: read(ROOT / f"data/art_staged16_race{race}_drafts.json").get("units", {}) for race in (1, 2)}
    remaining = EXPECTED - ACCEPTED
    missing = [key for key in ordered(remaining) if key not in drafts[int(key.split(":")[0])]]
    if missing:
        raise ValueError("Missing packed draft definitions; nothing written: " + ", ".join(missing))
    merged = copy.deepcopy(accepted)
    for key in ordered(remaining):
        definition = copy.deepcopy(drafts[int(key.split(":")[0])][key])
        definition["status"] = "applied_unreviewed"
        definition["integration_provenance"] = copy.deepcopy(PROVENANCE)
        merged[key] = definition
    missing_files, references = [], set()
    for key in ordered(merged):
        paths = set(file_refs(merged[key]))
        if not paths:
            missing_files.append(f"{key}: no file references")
        for raw in sorted(paths):
            path = ROOT / raw.removeprefix("res://")
            if not path.is_file():
                missing_files.append(f"{key}: {raw}")
            references.add(raw)
    if missing_files:
        raise ValueError("Missing referenced files; nothing written:\n" + "\n".join(missing_files))
    if set(merged) != EXPECTED or any(merged[key] != accepted[key] for key in ACCEPTED):
        raise ValueError("44-key connection or accepted-definition preservation failed")
    manifest["units"] = {key: merged[key] for key in ordered(merged)}
    manifest["unreviewed_integration_provenance"] = copy.deepcopy(PROVENANCE)
    state.update(
        integrated_units=ordered(EXPECTED),
        integrated_new_unit_count=44,
        integrated_unit_counts_by_race={"0": 16, "1": 14, "2": 14},
        accepted_unit_count=21,
        applied_unreviewed_units=ordered(remaining),
        applied_unreviewed_unit_count=23,
        all_units_connected=True,
        all_units_complete=False,
        current_phase="all_units_connected_unreviewed_building",
        current_chat_art_work="all_units_connected_unreviewed_building",
        work_priority="connect_existing_art_then_build_without_additional_QA",
        unreviewed_integration_provenance=copy.deepcopy(PROVENANCE),
    )
    for row in registry:
        if f"{row['race']}:{row['id']}" in remaining:
            row.update(integrated=True, integration_status="applied_unreviewed", visual_review_status="not_run_user_requested_skip_QA")
    summary = {"connected_units": 44, "accepted_units_preserved": 21, "applied_unreviewed_units": 23,
               "referenced_files_present": len(references), "qa_performed": False, "dry_run": args.dry_run}
    if not args.dry_run:
        stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        backup = ROOT / "build/staged16_20261024" / f"connection-backup-{stamp}-{uuid.uuid4().hex[:6]}"
        backup.mkdir(parents=True)
        saved = []
        for path in (MANIFEST, STATE, REGISTRY):
            destination = backup / path.name
            contents = path.read_bytes()
            destination.write_bytes(contents)
            saved.append({"original": str(path.relative_to(ROOT)), "backup": str(destination.relative_to(ROOT)),
                          "sha256": hashlib.sha256(contents).hexdigest()})
        atomic_json(backup / "backup-provenance.json", {**PROVENANCE, "original_files": saved})
        print("Backup: " + str(backup))
        atomic_json(MANIFEST, manifest)
        atomic_json(STATE, state)
        atomic_json(REGISTRY, registry)
        written = read(MANIFEST)["units"]
        if set(written) != EXPECTED or read(STATE)["accepted_units"] != accepted_list or any(written[key] != accepted[key] for key in ACCEPTED):
            raise ValueError("Saved accepted records differ; restore the printed backup before continuing")
        summary["backup_directory"] = str(backup.relative_to(ROOT))
        atomic_json(backup / "connection-result.json", summary)
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("CONNECTION FAILED: " + str(error), file=sys.stderr)
        raise SystemExit(1)
