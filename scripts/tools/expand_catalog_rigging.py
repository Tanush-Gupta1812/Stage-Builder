"""
Catalog Rigging Fields Expander for Stage-Builder Phase 3A
Adds data-driven rigging properties (mass, CoG, load ratings, SWL, wind, supports, and rigging points)
with generic placeholder values and explicit "placeholder": true markers.
"""

import json
from pathlib import Path

F34_LOAD_TABLE = [
    {"span_m": 2.0, "max_udl_kgm": 900.0, "max_point_load_kg": 900.0},
    {"span_m": 4.0, "max_udl_kgm": 440.0, "max_point_load_kg": 700.0},
    {"span_m": 6.0, "max_udl_kgm": 220.0, "max_point_load_kg": 460.0},
    {"span_m": 8.0, "max_udl_kgm": 120.0, "max_point_load_kg": 340.0},
    {"span_m": 10.0, "max_udl_kgm": 75.0, "max_point_load_kg": 260.0},
    {"span_m": 12.0, "max_udl_kgm": 50.0, "max_point_load_kg": 210.0},
]

F33_LOAD_TABLE = [
    {"span_m": 2.0, "max_udl_kgm": 550.0, "max_point_load_kg": 550.0},
    {"span_m": 4.0, "max_udl_kgm": 260.0, "max_point_load_kg": 420.0},
    {"span_m": 6.0, "max_udl_kgm": 130.0, "max_point_load_kg": 270.0},
    {"span_m": 8.0, "max_udl_kgm": 70.0, "max_point_load_kg": 190.0},
    {"span_m": 10.0, "max_udl_kgm": 42.0, "max_point_load_kg": 145.0},
    {"span_m": 12.0, "max_udl_kgm": 28.0, "max_point_load_kg": 115.0},
]

def enrich_catalog(catalog_path: Path):
    with open(catalog_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    assets = data.get("assets", [])

    for asset in assets:
        cat = asset.get("category", "")
        subcat = asset.get("subcategory", "")
        asset_id = asset.get("id", "")
        dims = asset.get("dimensions", {"x": 1.0, "y": 1.0, "z": 1.0})
        dx, dy, dz = dims.get("x", 1.0), dims.get("y", 1.0), dims.get("z", 1.0)

        # Baseline rigging fields
        asset["cog_offset"] = [0.0, round(dy * 0.5, 3), 0.0]

        # 1. Truss
        if cat == "Truss":
            is_tri = "tri" in asset_id or "triangle" in subcat.lower()
            profile = "triangle_f33" if is_tri else "box_f34"
            asset["truss_profile"] = profile
            asset["load_rating"] = {
                "placeholder": True,
                "table": F33_LOAD_TABLE if is_tri else F34_LOAD_TABLE
            }
            if "base" in asset_id or "base" in subcat.lower():
                asset["is_support"] = True
                asset["max_vertical_load_kg"] = 2500.0
                asset["max_overturning_moment_kgm"] = 1200.0
                asset["support_placeholder"] = True

        # 2. Rigging
        elif cat == "Rigging":
            if "hoist" in asset_id or "motor" in asset_id:
                cap = 1000.0
                if "05t" in asset_id or "0.5" in asset_id:
                    cap = 500.0
                elif "2t" in asset_id:
                    cap = 2000.0
                asset["swl_kg"] = cap
                asset["motor_capacity_kg"] = cap
                asset["placeholder"] = True
                asset["rigging_points"] = [
                    {"id": "top_hook", "pos": [0.0, dy, 0.0], "type": "ground", "capacity_kg": cap, "placeholder": True},
                    {"id": "bottom_hook", "pos": [0.0, 0.0, 0.0], "type": "hang", "capacity_kg": cap, "placeholder": True}
                ]
            elif "shackle" in asset_id:
                asset["swl_kg"] = 3250.0
                asset["placeholder"] = True
            elif "spanset" in asset_id:
                asset["swl_kg"] = 2000.0
                asset["placeholder"] = True
            elif "beam_clamp" in asset_id:
                asset["swl_kg"] = 1000.0
                asset["placeholder"] = True
            elif "bridle" in asset_id:
                asset["swl_kg"] = 1500.0
                asset["placeholder"] = True
            elif "safety" in asset_id:
                asset["swl_kg"] = 100.0
                asset["is_safety_bond"] = True
                asset["placeholder"] = True

        # 3. Roof & Structure
        elif cat == "Roof & Structure":
            if "tower" in asset_id or "scaffold" in asset_id or "ground_support" in asset_id:
                asset["is_support"] = True
                asset["max_vertical_load_kg"] = 4000.0
                asset["max_overturning_moment_kgm"] = 3500.0
                asset["support_placeholder"] = True
            # Wind exposure for roofs/tents
            asset["wind_area_m2"] = round(dx * dy, 2)
            asset["drag_coefficient"] = 1.2
            asset["wind_placeholder"] = True

        # 4. Lighting
        elif cat == "Lighting":
            # Hang point on top
            asset["rigging_points"] = [
                {"id": "clamp", "pos": [0.0, dy, 0.0], "type": "hang", "capacity_kg": 50.0, "placeholder": True}
            ]

        # 5. Audio
        elif cat == "Audio":
            if "line_array" in asset_id or "array" in subcat.lower():
                asset["rigging_points"] = [
                    {"id": "rig_top", "pos": [0.0, dy, 0.0], "type": "hang", "capacity_kg": 1500.0, "placeholder": True},
                    {"id": "rig_bottom", "pos": [0.0, 0.0, 0.0], "type": "hang", "capacity_kg": 1500.0, "placeholder": True}
                ]
                asset["splay_angles"] = [0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 7.5, 10.0]
                asset["max_cabinets"] = 16
                asset["array_placeholder"] = True

        # 6. Video
        elif cat == "Video":
            asset["wind_area_m2"] = round(dx * dy, 2)
            asset["drag_coefficient"] = 1.2
            asset["wind_placeholder"] = True
            if "led" in asset_id or "panel" in asset_id or "screen" in asset_id:
                asset["rigging_points"] = [
                    {"id": "hang_mount", "pos": [0.0, dy, 0.0], "type": "hang", "capacity_kg": 100.0, "placeholder": True}
                ]

        # 7. Power & Ballast
        elif cat == "Power":
            if "ibc" in asset_id or "tank" in asset_id:
                asset["is_ballast"] = True
                asset["ballast_mass_kg"] = 1050.0
                asset["ballast_placeholder"] = True
            elif "concrete" in asset_id or "ballast" in asset_id:
                asset["is_ballast"] = True
                asset["ballast_mass_kg"] = 1000.0
                asset["ballast_placeholder"] = True

        # 8. Environment & Dressing (wind exposure for banners/drapes)
        elif cat == "Environment & Dressing":
            if "banner" in asset_id or "drape" in asset_id or "backdrop" in asset_id:
                asset["wind_area_m2"] = round(dx * dy, 2)
                asset["drag_coefficient"] = 1.1
                asset["wind_placeholder"] = True

    with open(catalog_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"Enriched {len(assets)} assets with data-driven rigging fields in {catalog_path}")

if __name__ == "__main__":
    cat_file = Path(__file__).resolve().parent.parent.parent / "data" / "catalog.json"
    enrich_catalog(cat_file)

