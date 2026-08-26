#!/usr/bin/env python3
"""
split.py

Splits a Godot 4 TileMapLayer scene into one TileMapLayer scene per distinct
tile (identified by source_id + atlas coordinates), then updates the map scene
so it instances all of the resulting layers.

The map scene is *edited in place*, not regenerated: every node that isn't a
split tile layer (Player, StaticBody2D collision walls, Entities/NPCs, chests,
enemy spawners, Altar, ...) is migrated over verbatim, along with its
properties, children, sub_resources and ext_resources. Friendly names you gave
the layers in the Godot editor ("path", "walls", ...) are also carried over by
matching each layer node to the tile it draws, so re-splitting doesn't undo
your renames.

USAGE
    python3 split.py --map Map.tscn --layer Layer_0_0.tscn

    # see what would change without touching anything
    python3 split.py --map Map.tscn --layer Layer_0_0.tscn --dry-run

--map must point at the *live* map scene you want to keep (the one with your
entities in it), not at the bare stub your map exporter produced. Tile data
comes from --layer, so the stub isn't needed at all.

Run it from inside your Godot project folder (or point --outdir at the project
folder) so the res:// paths written into the scenes stay correct.

NOTE
    The exported --layer scene is the source of truth for tile placement. Tiles
    you hand-drew into an already-split layer inside Godot are not visible to
    the exporter and will not survive a re-split; the script warns when it sees
    a layer whose contents no longer match a single tile.

CUSTOMIZING NAMES
    Names are normally remembered from the map scene. NAME_MAP below only
    supplies the *initial* name for a tile that has no node yet. Anything not
    listed falls back to an auto-generated name like "tile_s0_0_0".
"""

import argparse
import re
import shutil
import sys
from collections import Counter, defaultdict
from pathlib import Path

# Map (source_id, atlas_x, atlas_y) -> friendly layer name, used only the first
# time a tile shows up. After that the name lives in the map scene, so renaming
# a layer in Godot is enough. e.g.
# NAME_MAP = {
#     (0, 0, 0): "water",
#     (0, 1, 0): "stone",
#     (0, 2, 0): "wall",
# }
NAME_MAP = {}

# Every section header Godot writes in a .tscn / .tres file. Restricting to
# these keeps multi-line property values from being mistaken for sections.
SECTION_KINDS = (
    "gd_scene", "gd_resource", "ext_resource", "sub_resource",
    "resource", "node", "connection", "editable",
)
SECTION_RE = re.compile(
    r"^\[(?P<kind>" + "|".join(SECTION_KINDS) + r")(?P<attrs>\s[^\]]*)?\]\s*$"
)
ATTR_RE = re.compile(
    r'([A-Za-z_][A-Za-z0-9_]*)='
    r'("(?:[^"\\]|\\.)*"|(?:Ext|Sub)Resource\("[^"]*"\)|[^\s\]]+)'
)
TILE_DATA_RE = re.compile(r"tile_map_data\s*=\s*PackedByteArray\(([^)]*)\)")
EXT_REF_RE = re.compile(r'ExtResource\("([^"]*)"\)')
SUB_REF_RE = re.compile(r'SubResource\("([^"]*)"\)')
AUTO_NAME_RE = re.compile(r"^Layer_tile_s(-?\d+)_(-?\d+)_(-?\d+)$")

CELL_SIZE = 12  # bytes per cell: 6 little-endian int16 fields
HEADER_SIZE = 2  # bytes of format header before the cells


# --------------------------------------------------------------------------
# .tscn parsing
# --------------------------------------------------------------------------

class Section:
    """One [header] plus the property lines that follow it."""

    def __init__(self, kind, header, attrs, body=None):
        self.kind = kind
        self.header = header
        self.attrs = attrs
        self.body = body if body is not None else []

    def text(self):
        return "\n".join([self.header] + self.body)

    # node-only helpers -----------------------------------------------------
    @property
    def name(self):
        return self.attrs.get("name")

    @property
    def parent(self):
        return self.attrs.get("parent")

    @property
    def instance_id(self):
        m = EXT_REF_RE.search(self.attrs.get("instance", ""))
        return m.group(1) if m else None

    def path(self):
        """Node path as other sections would spell it in `parent=`."""
        if self.parent is None:
            return "."
        if self.parent == ".":
            return self.name
        return f"{self.parent}/{self.name}"


def unquote(value):
    if value is None:
        return None
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    return value


def parse_scene(text):
    """Split a .tscn into (preamble_blank_lines, [Section, ...])."""
    sections = []
    current = None
    for line in text.splitlines():
        m = SECTION_RE.match(line)
        if m:
            attrs = {
                k: unquote(v)
                for k, v in ATTR_RE.findall(m.group("attrs") or "")
            }
            current = Section(m.group("kind"), line, attrs)
            sections.append(current)
        elif current is not None:
            current.body.append(line)
        # lines before the first section can only be blank; drop them
    for s in sections:
        while s.body and not s.body[-1].strip():
            s.body.pop()
    return sections


def render_scene(sections):
    """Re-emit a scene using Godot's own spacing: consecutive ext_resource
    lines are packed together, everything else is separated by a blank line."""
    out = []
    for i, s in enumerate(sections):
        if i:
            packed = (s.kind == "ext_resource"
                      and sections[i - 1].kind == "ext_resource"
                      and not sections[i - 1].body)
            if not packed:
                out.append("")
        out.append(s.text())
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------
# tile_map_data codec
# --------------------------------------------------------------------------

def i16(lo, hi):
    v = lo + hi * 256
    return v - 65536 if v >= 32768 else v


def u16_bytes(v):
    v &= 0xFFFF
    return [v & 0xFF, (v >> 8) & 0xFF]


def parse_tile_map_data(text, what):
    """Return (header_bytes, [(x, y, source_id, atlas_x, atlas_y, alt), ...])."""
    m = TILE_DATA_RE.search(text)
    if not m:
        raise ValueError(f"No tile_map_data found in {what}")
    data = [int(v.strip()) for v in m.group(1).split(",") if v.strip() != ""]
    if (len(data) - HEADER_SIZE) % CELL_SIZE != 0:
        raise ValueError(
            f"Unexpected tile_map_data length ({len(data)} bytes) in {what}; "
            f"cannot align to {CELL_SIZE}-byte cells after a "
            f"{HEADER_SIZE}-byte header."
        )
    header = data[:HEADER_SIZE]
    body = data[HEADER_SIZE:]
    cells = []
    for i in range(0, len(body), CELL_SIZE):
        c = body[i:i + CELL_SIZE]
        cells.append(tuple(i16(c[j], c[j + 1]) for j in range(0, CELL_SIZE, 2)))
    return header, cells


def cells_to_byte_string(header, cells):
    out = list(header)
    for cell in cells:
        for v in cell:
            out.extend(u16_bytes(v))
    return ", ".join(str(b) for b in out)


def tile_key_of_file(path):
    """The tile a split layer scene draws, or None if it can't be determined.

    Reads the actual cells so a renamed file (Layer_water.tscn) still resolves.
    Falls back to the auto-generated filename when the file is gone.
    """
    if path.exists():
        try:
            _, cells = parse_tile_map_data(
                path.read_text(encoding="utf-8"), path.name
            )
        except ValueError:
            cells = []
        if cells:
            counts = Counter((c[2], c[3], c[4]) for c in cells)
            key, n = counts.most_common(1)[0]
            if len(counts) > 1:
                warn(f"{path.name} holds {len(counts)} different tiles "
                     f"({n}/{len(cells)} cells are {key}); treating it as "
                     f"{key}. Hand-drawn tiles in this layer will be lost.")
            return key
    m = AUTO_NAME_RE.match(path.stem)
    return tuple(int(g) for g in m.groups()) if m else None


def tile_name(key):
    source_id, ax, ay = key
    return NAME_MAP.get(key, f"tile_s{source_id}_{ax}_{ay}")


# --------------------------------------------------------------------------
# res:// paths
# --------------------------------------------------------------------------

def find_project_root(start):
    for d in [start.resolve()] + list(start.resolve().parents):
        if (d / "project.godot").exists():
            return d
    return None


def res_path(path, project_root):
    if project_root is None:
        return path.name
    try:
        return "res://" + path.resolve().relative_to(project_root).as_posix()
    except ValueError:
        return path.name


def warn(msg):
    sys.stdout.flush()
    print(f"  ! {msg}", file=sys.stderr)
    sys.stderr.flush()


# --------------------------------------------------------------------------
# layer scene output
# --------------------------------------------------------------------------

def write_layer_scene(out_path, node_name, tileset_line, tileset_id,
                      header, cells, dry_run):
    """Create or update one split layer scene.

    An existing file keeps its node name, tile_set reference and every other
    property (collision_enabled, z_index, y_sort_enabled, ...) — only
    tile_map_data is swapped, so per-layer tweaks made in Godot survive.
    """
    byte_str = cells_to_byte_string(header, cells)
    if out_path.exists():
        text = out_path.read_text(encoding="utf-8")
        existing_tileset = re.search(
            r'\[ext_resource type="TileSet"[^\]]*path="([^"]+)"', text
        )
        wanted_tileset = re.search(r'path="([^"]+)"', tileset_line)
        if (existing_tileset and wanted_tileset
                and existing_tileset.group(1) != wanted_tileset.group(1)):
            warn(f"{out_path.name} points at tileset "
                 f"{existing_tileset.group(1)} but the source layer uses "
                 f"{wanted_tileset.group(1)}; keeping the existing one.")
        if TILE_DATA_RE.search(text):
            new_text = TILE_DATA_RE.sub(
                lambda _: f"tile_map_data = PackedByteArray({byte_str})",
                text, count=1,
            )
        else:
            new_text = text.rstrip("\n") + \
                f"\ntile_map_data = PackedByteArray({byte_str})\n"
        action = "updated" if new_text != text else "unchanged"
    else:
        new_text = (
            "[gd_scene load_steps=2 format=3]\n\n"
            f"{tileset_line}\n\n"
            f'[node name="{node_name}" type="TileMapLayer"]\n'
            "collision_enabled = false\n"
            f'tile_set = ExtResource("{tileset_id}")\n'
            f"tile_map_data = PackedByteArray({byte_str})\n"
        )
        action = "created"
    if not dry_run and action != "unchanged":
        out_path.write_text(new_text, encoding="utf-8")
    return action


def get_tileset_ext_resource(text):
    """Reuse the source layer's TileSet ext_resource line verbatim."""
    m = re.search(r'\[ext_resource type="TileSet"[^\]]*\]', text)
    if not m:
        raise ValueError("No TileSet ext_resource found in layer scene")
    line = m.group(0)
    id_m = re.search(r'id="([^"]+)"', line)
    if not id_m:
        raise ValueError(f"TileSet ext_resource has no id: {line}")
    return line, id_m.group(1)


# --------------------------------------------------------------------------
# map scene merge
# --------------------------------------------------------------------------

def blank_map_sections():
    return parse_scene(
        "[gd_scene format=3]\n\n"
        '[node name="map" type="Node2D"]\n'
    )


def classify_layer_nodes(sections, ext_by_id, map_dir):
    """Return {node_path: (section, tile_key, layer_path)} for split layers.

    A node counts as a split tile layer only if the scene it instances really
    is a TileMapLayer holding tile_map_data. That is what keeps player.tscn —
    also a PackedScene instance — from being swept up and deleted.
    """
    layers = {}
    for s in sections:
        if s.kind != "node" or s.instance_id is None:
            continue
        ext = ext_by_id.get(s.instance_id)
        if ext is None or ext.attrs.get("type") != "PackedScene":
            continue
        target = resolve_res_path(ext.attrs.get("path", ""), map_dir)
        if target is None:
            continue
        if target.exists():
            text = target.read_text(encoding="utf-8")
            if 'type="TileMapLayer"' not in text or not TILE_DATA_RE.search(text):
                continue
        elif not AUTO_NAME_RE.match(target.stem):
            continue
        key = tile_key_of_file(target)
        if key is None:
            warn(f'cannot tell which tile "{s.name}" draws '
                 f"({target.name}); leaving it untouched.")
            continue
        layers[s.path()] = (s, key, target)
    return layers


def resolve_res_path(path_str, map_dir):
    if not path_str:
        return None
    if path_str.startswith("res://"):
        root = find_project_root(map_dir)
        if root is None:
            return None
        return root / path_str[len("res://"):]
    return (map_dir / path_str)


def descendants_of(sections, node_path):
    prefix = node_path + "/"
    return [
        s for s in sections
        if s.kind == "node" and s.parent is not None
        and (s.parent == node_path or s.parent.startswith(prefix))
    ]


def free_ext_id(used, index):
    candidate = f"layer_{index}_id"
    n = index
    while candidate in used:
        n += 1
        candidate = f"layer_{n}_id"
    used.add(candidate)
    return candidate


def validate(sections):
    """Catch exactly the breakage that emptied Map.tscn last time."""
    errors = []
    ext_ids = {s.attrs["id"] for s in sections
               if s.kind == "ext_resource" and "id" in s.attrs}
    sub_ids = {s.attrs["id"] for s in sections
               if s.kind == "sub_resource" and "id" in s.attrs}
    node_paths = {s.path() for s in sections if s.kind == "node"}
    for s in sections:
        if s.kind not in ("node", "sub_resource", "connection", "resource"):
            continue
        where = s.attrs.get("name") or s.kind
        for ref in EXT_REF_RE.findall(s.text()):
            if ref not in ext_ids:
                errors.append(f'"{where}" references missing '
                              f'ext_resource id "{ref}"')
        for ref in SUB_REF_RE.findall(s.text()):
            if ref not in sub_ids:
                errors.append(f'"{where}" references missing '
                              f'sub_resource id "{ref}"')
        if s.kind == "node" and s.parent not in (None, ".") \
                and s.parent not in node_paths:
            errors.append(f'"{where}" is parented to missing node '
                          f'"{s.parent}"')
    return errors


def update_load_steps(sections):
    """Keep the load_steps hint in the [gd_scene] header consistent."""
    head = sections[0]
    if head.kind != "gd_scene" or "load_steps" not in head.attrs:
        return
    steps = 1 + sum(
        1 for s in sections if s.kind in ("ext_resource", "sub_resource")
    )
    head.header = re.sub(r"load_steps=\d+", f"load_steps={steps}", head.header)
    head.attrs["load_steps"] = str(steps)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="Split a TileMapLayer scene per tile and merge the result "
                    "into an existing map scene without disturbing its other "
                    "nodes."
    )
    ap.add_argument("--map", required=True,
                    help="Path to the live Map.tscn to update in place")
    ap.add_argument("--layer", required=True, action="append",
                    help="Exported layer scene to split (repeatable)")
    ap.add_argument("--migrate-from", default=None, metavar="MAP",
                    help="Take the nodes to preserve from this map instead of "
                         "from --map. Use it when your exporter has already "
                         "overwritten Map.tscn with a bare stub, e.g. "
                         "git show HEAD:path/to/Map.tscn > good.tscn")
    ap.add_argument("--outdir", default=None,
                    help="Where the split layer scenes go "
                         "(default: the map's directory)")
    ap.add_argument("--dry-run", action="store_true",
                    help="Report what would change; write nothing")
    ap.add_argument("--no-backup", action="store_true",
                    help="Skip writing Map.tscn.bak")
    ap.add_argument("--prune", action="store_true",
                    help="Also delete layer scenes for tiles that vanished")
    args = ap.parse_args()

    map_path = Path(args.map)
    outdir = Path(args.outdir) if args.outdir else map_path.parent
    outdir.mkdir(parents=True, exist_ok=True)
    project_root = find_project_root(outdir)
    if project_root is None:
        warn("no project.godot found above the output directory; layer paths "
             "will be written as bare filenames.")

    # ---- read the source layer(s) ----------------------------------------
    header = None
    cells = []
    tileset_line = tileset_id = None
    for layer_arg in args.layer:
        layer_path = Path(layer_arg)
        layer_text = layer_path.read_text(encoding="utf-8")
        h, c = parse_tile_map_data(layer_text, layer_path.name)
        if header is None:
            header = h
            tileset_line, tileset_id = get_tileset_ext_resource(layer_text)
        cells.extend(c)

    groups = defaultdict(list)
    for cell in cells:
        groups[(cell[2], cell[3], cell[4])].append(cell)

    # ---- read the map we are merging into --------------------------------
    # --migrate-from lets the nodes come from a known-good copy while the
    # result is still written to --map.
    base_path = Path(args.migrate_from) if args.migrate_from else map_path
    if base_path.exists():
        sections = parse_scene(base_path.read_text(encoding="utf-8"))
        if base_path != map_path:
            print(f"Migrating nodes from {base_path} into {map_path}.")
    else:
        warn(f"{base_path} does not exist; creating a new map scene.")
        sections = blank_map_sections()

    ext_by_id = {s.attrs["id"]: s for s in sections
                 if s.kind == "ext_resource" and "id" in s.attrs}
    # Relative ext_resource paths resolve against the scene they were read from.
    base_dir = base_path.parent if str(base_path.parent) else Path(".")
    existing_layers = classify_layer_nodes(sections, ext_by_id, base_dir)

    node_count = sum(1 for s in sections if s.kind == "node")
    carried = node_count - len(existing_layers)
    if carried <= 1 and node_count > 0:
        warn(f"{base_path.name} has no nodes besides its layers — if you meant "
             "to keep your entities, point --map (or --migrate-from) at the "
             "live map scene, not at an exported stub.")

    print(f"Found {len(cells)} tiles across {len(groups)} distinct tile types.")
    print(f"Map scene: {node_count} nodes, {len(existing_layers)} of them "
          f"split layers, {carried} to migrate untouched.")

    # ---- decide the layer set and its draw order -------------------------
    # Existing layers keep their relative order (that is the artist's chosen
    # draw order); brand-new tiles are appended after the last one.
    by_key = defaultdict(list)
    for section, key, target in existing_layers.values():
        by_key[key].append((section, target))

    key_to_existing = {}
    for key, entries in by_key.items():
        if len(entries) > 1:
            others = ", ".join(f'"{s.name}"' for s, _ in entries[1:])
            warn(f'{len(entries)} nodes draw tile {key}; syncing '
                 f'"{entries[0][0].name}" and leaving {others} alone.')
        key_to_existing[key] = entries[0]

    ordered_keys = []
    seen = set()
    for _, key, _ in existing_layers.values():
        if key in groups and key not in seen:
            ordered_keys.append(key)
            seen.add(key)
    ordered_keys += [k for k in sorted(groups) if k not in seen]
    dropped = [k for k in key_to_existing if k not in groups]

    # ---- write the layer scenes ------------------------------------------
    used_ext_ids = set(ext_by_id)
    layer_plan = []  # (key, node_section_or_None, out_path, node_name)
    for idx, key in enumerate(ordered_keys, start=1):
        if key in key_to_existing:
            section, out_path = key_to_existing[key]
            node_name = section.name
        else:
            section = None
            name = tile_name(key)
            out_path = outdir / f"Layer_{name}.tscn"
            node_name = f"Layer_{name}"
        action = write_layer_scene(
            out_path, node_name, tileset_line, tileset_id,
            header, groups[key], args.dry_run,
        )
        layer_plan.append((key, section, out_path, node_name))
        tag = "keep" if section is not None else "NEW"
        print(f"  [{tag:4}] source={key[0]} atlas=({key[1]},{key[2]}) -> "
              f"{len(groups[key]):5d} tiles -> {out_path.name} "
              f'({action}) as "{node_name}"')

    for key in dropped:
        _, out_path = key_to_existing[key]
        for section, _ in by_key[key]:
            print(f'  [drop] "{section.name}" ({out_path.name}) — tile {key} '
                  f"is no longer used in the source layer")
        if args.prune and not args.dry_run and out_path.exists():
            out_path.unlink()

    # ---- rebuild the map scene -------------------------------------------
    # Drop the sections belonging to removed layers, then insert the ones we
    # are adding. Everything else is left exactly as it was.
    doomed = set()
    for key in dropped:
        for section, _ in by_key[key]:
            doomed.add(id(section))
            for child in descendants_of(sections, section.path()):
                doomed.add(id(child))
    sections = [s for s in sections if id(s) not in doomed]

    # An ext_resource only goes away once nothing else points at it.
    orphan_candidates = {
        section.instance_id
        for key in dropped for section, _ in by_key[key]
        if section.instance_id is not None
    }
    still_referenced = set()
    for s in sections:
        if s.kind != "ext_resource":
            still_referenced.update(EXT_REF_RE.findall(s.text()))
    sections = [
        s for s in sections
        if not (s.kind == "ext_resource"
                and s.attrs.get("id") in orphan_candidates
                and s.attrs.get("id") not in still_referenced)
    ]

    new_nodes = []
    for key, section, out_path, node_name in layer_plan:
        if section is not None:
            continue  # existing node and its ext_resource stay as-is
        ext_id = free_ext_id(used_ext_ids, len(used_ext_ids) + 1)
        ext_line = (f'[ext_resource type="PackedScene" '
                    f'path="{res_path(out_path, project_root)}" '
                    f'id="{ext_id}"]')
        new_ext = parse_scene(ext_line)[0]
        last_ext = max(
            (i for i, s in enumerate(sections) if s.kind == "ext_resource"),
            default=0,
        )
        sections.insert(last_ext + 1, new_ext)
        new_nodes.append(parse_scene(
            f'[node name="{node_name}" parent="." '
            f'instance=ExtResource("{ext_id}")]'
        )[0])

    if new_nodes:
        # Insert after the last existing layer node so entities keep drawing
        # on top; if there are none, right after the root node.
        kept_layer_ids = {id(s) for _, s, _, _ in layer_plan if s is not None}
        anchor = None
        for i, s in enumerate(sections):
            if id(s) in kept_layer_ids:
                anchor = i
        if anchor is None:
            anchor = next(i for i, s in enumerate(sections) if s.kind == "node")
        for offset, node in enumerate(new_nodes, start=1):
            sections.insert(anchor + offset, node)

    update_load_steps(sections)

    errors = validate(sections)
    if errors:
        print("\nAborting: the rewritten map scene would be broken:",
              file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    output = render_scene(sections)
    if args.dry_run:
        print(f"\n[dry run] {map_path} would keep "
              f"{sum(1 for s in sections if s.kind == 'node')} nodes, "
              f"{sum(1 for s in sections if s.kind == 'ext_resource')} "
              f"ext_resources and "
              f"{sum(1 for s in sections if s.kind == 'sub_resource')} "
              f"sub_resources. Nothing written.")
        return 0

    if map_path.exists() and not args.no_backup:
        shutil.copy2(map_path, map_path.with_suffix(map_path.suffix + ".bak"))
        print(f"\nBackup written to {map_path.name}.bak")
    map_path.write_text(output, encoding="utf-8")
    print(f"Updated map scene written to {map_path} "
          f"({sum(1 for s in sections if s.kind == 'node')} nodes, "
          f"reference check passed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
