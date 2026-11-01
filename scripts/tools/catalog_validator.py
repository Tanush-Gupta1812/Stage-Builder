"""
Catalog Schema Validator for Stage-Builder
Validates data/catalog.json ensuring all assets adhere to physical real-world scale,
contain necessary snap points, dimensions, weights, and generator IDs.
"""

import json
import sys
from pathlib import Path

REQUIRED_ASSET_FIELDS = [
    "id",
    "name",
    "category",
    "dimensions",
    "weight_kg",
    "mesh_generator",
    "snap_points",
    "tags"
]

REQUIRED_DIMENSION_KEYS = ["x", "y", "z"]

def validate_catalog(json_path: Path) -> bool:
    if not json_path.exists():
        print(f"ERROR: Catalog file not found at {json_path}")
        return False

    with open(json_path, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON syntax in {json_path}: {e}")
            return False

    assets = data.get("assets", [])
    if not assets:
        print("ERROR: 'assets' array is empty or missing.")
        return False

    seen_ids = set()
    categories = {}
    total_snap_points = 0
    errors = []

    for idx, asset in enumerate(assets):
        asset_id = asset.get("id", f"<index {idx}>")

        # Check required fields
        for field in REQUIRED_ASSET_FIELDS:
            if field not in asset:
                errors.append(f"Asset '{asset_id}' missing required field: '{field}'")

        # Check unique ID
        if asset_id in seen_ids:
            errors.append(f"Duplicate asset ID found: '{asset_id}'")
        seen_ids.add(asset_id)

        # Check dimensions
        dims = asset.get("dimensions", {})
        for axis in REQUIRED_DIMENSION_KEYS:
            val = dims.get(axis)
            if not isinstance(val, (int, float)) or val <= 0:
                errors.append(f"Asset '{asset_id}' invalid dimension '{axis}': {val} (must be positive number)")

        # Check weight
        weight = asset.get("weight_kg")
        if not isinstance(weight, (int, float)) or weight < 0:
            errors.append(f"Asset '{asset_id}' invalid weight: {weight} (must be non-negative)")

        # Check snap points
        snaps = asset.get("snap_points", [])
        total_snap_points += len(snaps)
        for s_idx, snap in enumerate(snaps):
            if "pos" not in snap or not isinstance(snap["pos"], list) or len(snap["pos"]) != 3:
                errors.append(f"Asset '{asset_id}' snap_point[{s_idx}] invalid 'pos': expected [x, y, z]")
            if "normal" not in snap or not isinstance(snap["normal"], list) or len(snap["normal"]) != 3:
                errors.append(f"Asset '{asset_id}' snap_point[{s_idx}] invalid 'normal': expected [x, y, z]")
            if "tag" not in snap or not isinstance(snap["tag"], str):
                errors.append(f"Asset '{asset_id}' snap_point[{s_idx}] missing or invalid 'tag'")

        category = asset.get("category", "Uncategorized")
        categories[category] = categories.get(category, 0) + 1

    if errors:
        print(f"Validation FAILED with {len(errors)} error(s):")
        for err in errors:
            print(f"  - {err}")
        return False

    print("==================================================")
    print("Stage-Builder Catalog Validation SUCCESS")
    print(f"Total Assets: {len(assets)}")
    print(f"Total Snap Points: {total_snap_points}")
    print("Categories:")
    for cat, count in sorted(categories.items()):
        print(f"  - {cat}: {count} item(s)")
    print("==================================================")
    return True

if __name__ == "__main__":
    catalog_path = Path(__file__).resolve().parent.parent.parent / "data" / "catalog.json"
    success = validate_catalog(catalog_path)
    sys.exit(0 if success else 1)
