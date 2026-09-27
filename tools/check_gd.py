#!/usr/bin/env python3
"""Lightweight structural sanity check for the .gd files touched by the
rebalance. Godot isn't available in this environment, so this catches the
mistakes that are cheap to make when hand-editing GDScript: mixed indentation,
unbalanced brackets, and functions with no body.
"""
import sys

FILES = [
    "battle/battle.gd",
    "assets/global/game_manager.gd",
]


def check(path):
    problems = []
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()

    for i, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        if line.startswith(" "):
            problems.append(f"{path}:{i}: leading space (file mixes tabs and spaces)")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not raw.startswith("\t") and not line.startswith("func ") and not line.startswith("@"):
            if not line.startswith(("extends", "var ", "const ", "signal ", "enum ", "export")):
                problems.append(f"{path}:{i}: unexpected top-level line: {line[:60]}")

    # Bracket balance, ignoring strings and comments.
    depth = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    for i, raw in enumerate(lines, 1):
        line = raw.split("#")[0]
        for ch in line:
            if ch in depth:
                depth[ch] += 1
            elif ch in pairs:
                depth[pairs[ch]] -= 1
    for ch, count in depth.items():
        if count != 0:
            problems.append(f"{path}: unbalanced '{ch}' (net {count})")

    # Every func must be followed by an indented body.
    for i, raw in enumerate(lines):
        if raw.startswith("func "):
            j = i + 1
            body = []
            while j < len(lines) and (lines[j].startswith("\t") or not lines[j].strip()):
                body.append(lines[j])
                j += 1
            if not any(b.strip() and not b.strip().startswith("#") for b in body):
                problems.append(f"{path}:{i+1}: func has no body")

    return problems


def main():
    all_problems = []
    for path in FILES:
        try:
            all_problems.extend(check(path))
        except FileNotFoundError:
            all_problems.append(f"{path}: missing")
    if all_problems:
        print("PROBLEMS FOUND:")
        for p in all_problems:
            print("  " + p)
        sys.exit(1)
    print("Structure OK for: " + ", ".join(FILES))


if __name__ == "__main__":
    main()
