#!/usr/bin/env python3
"""Rename the bundle identifiers for a personal, sideloaded build.

The upstream identifiers (`com.apoorvdarshan.*`, `group.com.apoorvdarshan.*`,
`iCloud.com.apoorvdarshan.*`) are registered to the author's Apple team, so a
different team cannot create App IDs for them. This script rewrites them in the
Xcode project, the entitlements files and the Swift sources that hardcode them
(App Group, in-app purchase product IDs, misc identifiers).

Usage (from the repository root):

    python scripts/sideload/rename_bundle_id.py com.fudai.sideload

Run it once. It prints every file it changed.
"""

from __future__ import annotations

import pathlib
import sys

OLD = "com.apoorvdarshan.calorietracker"
OLD_GROUP = "group.com.apoorvdarshan.calorietracker"
OLD_ICLOUD = "iCloud.com.apoorvdarshan.calorietracker"

# Text files that may contain an identifier. Binary assets are skipped.
SUFFIXES = {".swift", ".plist", ".pbxproj", ".entitlements", ".xcscheme", ".xcstrings", ".md", ".json", ".yml", ".yaml"}


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print(__doc__)
        return 2
    new = sys.argv[1].strip().rstrip(".")
    if not new or "." not in new:
        print("error: pass a reverse-DNS bundle identifier, e.g. com.fudai.sideload", file=sys.stderr)
        return 2

    replacements = [
        (OLD_ICLOUD, f"iCloud.{new}"),
        (OLD_GROUP, f"group.{new}"),
        (OLD, new),
    ]

    root = pathlib.Path(__file__).resolve().parents[2]
    changed: list[tuple[pathlib.Path, int]] = []

    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if ".git" in path.parts or "DerivedData" in path.parts:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        original = text
        hits = 0
        for old, replacement in replacements:
            hits += text.count(old)
            text = text.replace(old, replacement)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed.append((path.relative_to(root), hits))

    if not changed:
        print("No identifiers found — already renamed?")
        return 1

    for relative, hits in changed:
        print(f"  {relative}: {hits}")
    print(f"\nRenamed {sum(h for _, h in changed)} identifier(s) in {len(changed)} file(s) to {new}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
