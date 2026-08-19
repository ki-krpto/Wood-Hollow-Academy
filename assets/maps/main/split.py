#!/usr/bin/env python3
"""
split_tilemap_layers.py

Splits a Godot 4 TileMapLayer scene into one TileMapLayer scene per distinct
tile (identified by source_id + atlas coordinates), then rewrites the map
scene to instance all of the resulting layers instead of the single original
one. Layer 0 (the tile drawn first at a given cell) stays visually on the
bottom because scene layers are added in the same order as before.

USAGE
    python3 split_tilemap_layers.py \
        --map Map.tscn \
        --layer Layer_0_0.tscn \
        --outdir .

Run it from inside your Godot project folder (or point --outdir at the
project folder) so the res:// paths written into the scenes stay correct.

CUSTOMIZING NAMES
    Edit NAME_MAP below to give friendly names ("stone", "wall", "water"...)
    to specific (source_id, atlas_x, atlas_y) tiles. Anything not listed
    falls back to an auto-generated name like "tile_s0_0_0".
"""

import argparse
import re
import sys
from pathlib import Path
from collections import defaultdict

# Map (source_id, atlas_x, atlas_y) -> friendly layer name.
# Fill this in with your own tile categories, e.g.:
# NAME_MAP = {
#     (0, 0, 0): "water",
#     (0, 1, 0): "stone",
#     (0, 2, 0): "wall",
# }
NAME_MAP = {}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_tile_map_data(text: str):
    """Return (header_bytes, list_of_cells) where each cell is a tuple
    (x, y, source_id, atlas_x, atlas_y, alt)."""
    m = re.search(r"tile_map_data = PackedByteArray\(([^)]*)\)", text)
    if not m:
        raise ValueError("No tile_map_data found in layer scene")
    data = [int(v.strip()) for v in m.group(1).split(",") if v.strip() != ""]

    # tile_map_data is a 2-byte format header followed by 12 bytes per cell
    # (6 little-endian int16 values: x, y, source_id, atlas_x, atlas_y, alt).
    if (len(data) - 2) % 12 != 0:
        raise ValueError(
            f"Unexpected tile_map_data length ({len(data)} bytes); "
            "cannot align to 12-byte cells after a 2-byte header."
        )
    header = data[:2]
    body = data[2:]

    def i16(lo, hi):
        v = lo + hi * 256
        return v - 65536 if v >= 32768 else v

    def u16_bytes(v):
        v &= 0xFFFF
        return [v & 0xFF, (v >> 8) & 0xFF]

    cells = []
    for i in range(0, len(body), 12):
        c = body[i:i + 12]
        x = i16(c[0], c[1])
        y = i16(c[2], c[3])
        source_id = i16(c[4], c[5])
        ax = i16(c[6], c[7])
        ay = i16(c[8], c[9])
        alt = i16(c[10], c[11])
        cells.append((x, y, source_id, ax, ay, alt))

    return header, cells, u16_bytes


def get_tileset_ext_resource(text: str):
    """Return (line, resource_type, uid_or_none, path) for the TileSet
    ext_resource line in the layer scene, so we can reuse it verbatim."""
    m = re.search(
        r'\[ext_resource type="TileSet"[^\]]*\]',
        text,
    )
    if not m:
        raise ValueError("No TileSet ext_resource found in layer scene")
    line = m.group(0)
    path_m = re.search(r'path="([^"]+)"', line)
    id_m = re.search(r'id="([^"]+)"', line)
    uid_m = re.search(r'uid="([^"]+)"', line)
    return line, id_m.group(1), (uid_m.group(1) if uid_m else None), path_m.group(1)


def cells_to_bytes(header, cells, u16_bytes):
    out = list(header)
    for (x, y, source_id, ax, ay, alt) in cells:
        for v in (x, y, source_id, ax, ay, alt):
            out.extend(u16_bytes(v))
    return out


def tile_name(source_id, ax, ay):
    if (source_id, ax, ay) in NAME_MAP:
        return NAME_MAP[(source_id, ax, ay)]
    return f"tile_s{source_id}_{ax}_{ay}"


def write_layer_scene(out_path: Path, layer_node_name, tileset_id_str,
                       tileset_path, header, cells, u16_bytes):
    byte_list = cells_to_bytes(header, cells, u16_bytes)
    byte_str = ", ".join(str(b) for b in byte_list)
    content = (
        '[gd_scene load_steps=2 format=3]\n\n'
        f'[ext_resource type="TileSet" id="{tileset_id_str}" path="{tileset_path}"]\n\n'
        f'[node name="{layer_node_name}" type="TileMapLayer"]\n'
        'collision_enabled = false\n'
        f'tile_set = ExtResource("{tileset_id_str}")\n'
        f'tile_map_data = PackedByteArray({byte_str})\n'
    )
    out_path.write_text(content, encoding="utf-8")


def rewrite_map_scene(map_text: str, old_layer_node_name: str,
                       new_layers: list, root_node_name: str):
    """new_layers: list of (node_name, scene_filename)"""
    # Build fresh ext_resource block for each split layer.
    ext_lines = []
    node_lines = []
    for idx, (node_name, filename) in enumerate(new_layers, start=1):
        res_id = f"layer_{idx}_id"
        ext_lines.append(
            f'[ext_resource type="PackedScene" id="{res_id}" path="{filename}"]'
        )
        node_lines.append(
            f'[node name="{node_name}" parent="." instance=ExtResource("{res_id}")]'
        )

    # Remove the old ext_resource line(s) pointing at the original layer scene
    # and the old node line instancing it, then insert the new ones.
    lines = map_text.splitlines()
    kept = []
    for line in lines:
        if line.strip().startswith("[ext_resource") and "PackedScene" in line:
            continue
        if line.strip().startswith("[node") and f'name="{old_layer_node_name}"' in line:
            continue
        kept.append(line)

    # Insert new ext_resource lines right after the [gd_scene ...] header.
    result = []
    inserted_ext = False
    inserted_nodes = False
    for line in kept:
        result.append(line)
        if line.strip().startswith("[gd_scene") and not inserted_ext:
            result.append("")
            result.extend(ext_lines)
            inserted_ext = True
        if line.strip().startswith(f'[node name="{root_node_name}"') and not inserted_nodes:
            result.extend(node_lines)
            inserted_nodes = True

    # Collapse the accidental double blank line left where the old
    # ext_resource block used to sit.
    cleaned = []
    prev_blank = False
    for line in result:
        blank = (line.strip() == "")
        if blank and prev_blank:
            continue
        cleaned.append(line)
        prev_blank = blank

    return "\n".join(cleaned) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", required=True, help="Path to Map.tscn")
    ap.add_argument("--layer", required=True, help="Path to the layer scene to split, e.g. Layer_0_0.tscn")
    ap.add_argument("--outdir", default=".", help="Directory to write new layer scenes + updated Map.tscn into")
    args = ap.parse_args()

    map_path = Path(args.map)
    layer_path = Path(args.layer)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    layer_text = read_text(layer_path)
    map_text = read_text(map_path)

    header, cells, u16_bytes = parse_tile_map_data(layer_text)
    _, tileset_id_str, _, tileset_path = get_tileset_ext_resource(layer_text)

    old_layer_node_m = re.search(r'\[node name="([^"]+)" type="TileMapLayer"', layer_text)
    old_layer_node_name = old_layer_node_m.group(1) if old_layer_node_m else layer_path.stem

    groups = defaultdict(list)
    for (x, y, source_id, ax, ay, alt) in cells:
        groups[(source_id, ax, ay)].append((x, y, source_id, ax, ay, alt))

    print(f"Found {len(cells)} tiles across {len(groups)} distinct tile types:")
    new_layers = []
    for key in sorted(groups.keys()):
        source_id, ax, ay = key
        name = tile_name(*key)
        node_name = f"Layer_{name}"
        filename = f"Layer_{name}.tscn"
        out_path = outdir / filename
        write_layer_scene(
            out_path, node_name, tileset_id_str, tileset_path,
            header, groups[key], u16_bytes,
        )
        new_layers.append((node_name, filename))
        print(f"  source={source_id} atlas=({ax},{ay}) -> {len(groups[key])} tiles -> {filename}")

    root_node_m = re.search(r'\[node name="([^"]+)" type=', map_text)
    root_node_name = root_node_m.group(1) if root_node_m else "map"

    new_map_text = rewrite_map_scene(map_text, old_layer_node_name, new_layers, root_node_name)
    new_map_path = outdir / map_path.name
    new_map_path.write_text(new_map_text, encoding="utf-8")
    print(f"\nUpdated map scene written to {new_map_path}")


if __name__ == "__main__":
    main()