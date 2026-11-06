"""
Catalog Schema Validator for Stage-Builder (Phase 2)
Validates data/catalog.json ensuring all assets adhere to physical real-world scale,
contain necessary snap points, dimensions, weights, generator IDs, and optional variants.
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
    subcategories = {}
    total_snap_points = 0
    total_variants = 0
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

        # Check pivot normalization: resulting AABB min.y must be 0.0 within 1 mm
        dim_y = dims.get("y", 1.0)
        pivot_offset_y = asset.get("pivot_offset_y", dim_y * 0.5)
        resulting_min_y = -dim_y * 0.5 + pivot_offset_y
        if abs(resulting_min_y) > 0.001:
            errors.append(f"Asset '{asset_id}' pivot normalization failed: resulting AABB min.y = {resulting_min_y:.4f}m (expected 0.0 within 1mm)")

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

        # Check variants if present
        variants = asset.get("variants", [])
        total_variants += len(variants)
        for v_idx, variant in enumerate(variants):
            if "id" not in variant or "name" not in variant:
                errors.append(f"Asset '{asset_id}' variant[{v_idx}] must have 'id' and 'name'")

        # Phase 3 Rigging validation
        if "cog_offset" in asset:
            cog = asset["cog_offset"]
            if not isinstance(cog, list) or len(cog) != 3 or not all(isinstance(v, (int, float)) for v in cog):
                errors.append(f"Asset '{asset_id}' cog_offset must be a 3-element numeric list [x, y, z]")

        if "load_rating" in asset:
            lr = asset["load_rating"]
            if not isinstance(lr, dict) or "table" not in lr:
                errors.append(f"Asset '{asset_id}' load_rating must be dict with 'table'")
            elif not lr.get("placeholder", False):
                errors.append(f"Asset '{asset_id}' load_rating must have 'placeholder': true")
            else:
                for row in lr["table"]:
                    if not all(k in row for k in ("span_m", "max_udl_kgm", "max_point_load_kg")):
                        errors.append(f"Asset '{asset_id}' load_rating table row missing span_m, max_udl_kgm, or max_point_load_kg")

        if "swl_kg" in asset:
            swl = asset["swl_kg"]
            if not isinstance(swl, (int, float)) or swl <= 0:
                errors.append(f"Asset '{asset_id}' invalid swl_kg: {swl}")
            if not asset.get("placeholder", False):
                errors.append(f"Asset '{asset_id}' with swl_kg must have 'placeholder': true")

        if "motor_capacity_kg" in asset:
            mc = asset["motor_capacity_kg"]
            if not isinstance(mc, (int, float)) or mc <= 0:
                errors.append(f"Asset '{asset_id}' invalid motor_capacity_kg: {mc}")
            if not asset.get("placeholder", False):
                errors.append(f"Asset '{asset_id}' with motor_capacity_kg must have 'placeholder': true")

        if asset.get("is_support", False):
            mvl = asset.get("max_vertical_load_kg", 0)
            if not isinstance(mvl, (int, float)) or mvl <= 0:
                errors.append(f"Asset '{asset_id}' is_support must have positive max_vertical_load_kg")
            if not asset.get("placeholder", False):
                errors.append(f"Asset '{asset_id}' is_support must have 'placeholder': true")

        if "rigging_points" in asset:
            rps = asset["rigging_points"]
            if not isinstance(rps, list):
                errors.append(f"Asset '{asset_id}' rigging_points must be list")
            else:
                for rp_idx, rp in enumerate(rps):
                    if not isinstance(rp, dict) or "id" not in rp or "pos" not in rp or "type" not in rp:
                        errors.append(f"Asset '{asset_id}' rigging_point[{rp_idx}] missing id, pos, or type")
                    elif rp["type"] not in ("load", "hang", "ground"):
                        errors.append(f"Asset '{asset_id}' rigging_point[{rp_idx}] invalid type '{rp['type']}': must be load, hang, or ground")

        if "wind_area_m2" in asset:
            wa = asset["wind_area_m2"]
            if not isinstance(wa, (int, float)) or wa <= 0:
                errors.append(f"Asset '{asset_id}' invalid wind_area_m2: {wa}")

        category = asset.get("category", "Uncategorized")
        categories[category] = categories.get(category, 0) + 1

        subcat = asset.get("subcategory", "General")
        subcategories[subcat] = subcategories.get(subcat, 0) + 1

    if errors:
        print(f"Validation FAILED with {len(errors)} error(s):")
        for err in errors[:25]:
            print(f"  - {err}")
        if len(errors) > 25:
            print(f"  ... and {len(errors) - 25} more errors.")
        return False

    print("==================================================")
    print("Stage-Builder Phase 2 Catalog Validation SUCCESS")
    print(f"Total Assets: {len(assets)}")
    print(f"Total Snap Points: {total_snap_points}")
    print(f"Total Variants: {total_variants}")
    print(f"Categories ({len(categories)}):")
    for cat, count in sorted(categories.items()):
        print(f"  - {cat}: {count} item(s)")
    print(f"Subcategories: {len(subcategories)}")
    print("==================================================")
    return True

if __name__ == "__main__":
    catalog_path = Path(__file__).resolve().parent.parent.parent / "data" / "catalog.json"
    success = validate_catalog(catalog_path)
    sys.exit(0 if success else 1)
