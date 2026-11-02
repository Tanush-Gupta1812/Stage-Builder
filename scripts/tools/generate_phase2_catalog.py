"""
Phase 2 Catalog Generator for Stage-Builder
Generates a comprehensive 143-asset production catalog with accurate real-world dimensions (1 Godot unit = 1 meter),
physical weights, snap points, tags, subcategories, and material/color variants.
"""

import json
from pathlib import Path

def build_catalog() -> dict:
    assets = []

    # -------------------------------------------------------------
    # 1. TRUSS (22 items)
    # -------------------------------------------------------------
    box_lengths = [
        ("029m", "0.29m", 0.29, 4.5),
        ("05m", "0.5m", 0.5, 6.0),
        ("1m", "1m", 1.0, 9.2),
        ("15m", "1.5m", 1.5, 12.0),
        ("2m", "2m", 2.0, 15.0),
        ("25m", "2.5m", 2.5, 18.0),
        ("3m", "3m", 3.0, 21.0),
        ("4m", "4m", 4.0, 27.5),
    ]

    truss_variants = [
        {"id": "silver", "name": "Natural Aluminum", "material": "aluminum"},
        {"id": "black", "name": "Matte Black Powdercoat", "material": "aluminum_black"},
        {"id": "white", "name": "Gloss White", "material": "aluminum_white"}
    ]

    for code, label, length, weight in box_lengths:
        half_z = length * 0.5
        assets.append({
            "id": f"truss_box_{code}",
            "name": f"Box Truss {label} (F34)",
            "category": "Truss",
            "subcategory": "Box Truss",
            "dimensions": {"x": 0.29, "y": 0.29, "z": length},
            "weight_kg": weight,
            "mesh_generator": "gen_truss_box",
            "tags": ["truss", "box", "f34", "rigging", "aluminum", "29cm", label],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [0.0, 0.0, -half_z], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, half_z], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        })

    tri_lengths = [
        ("05m", "0.5m", 0.5, 4.2),
        ("1m", "1m", 1.0, 6.5),
        ("2m", "2m", 2.0, 10.5),
        ("3m", "3m", 3.0, 14.8),
    ]
    for code, label, length, weight in tri_lengths:
        half_z = length * 0.5
        assets.append({
            "id": f"truss_tri_{code}",
            "name": f"Triangle Truss {label} (F33)",
            "category": "Truss",
            "subcategory": "Triangle Truss",
            "dimensions": {"x": 0.29, "y": 0.26, "z": length},
            "weight_kg": weight,
            "mesh_generator": "gen_truss_tri",
            "tags": ["truss", "triangle", "f33", "rigging", "aluminum", label],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [0.0, 0.0, -half_z], "normal": [0.0, 0.0, -1.0], "tag": "truss_f33"},
                {"pos": [0.0, 0.0, half_z], "normal": [0.0, 0.0, 1.0], "tag": "truss_f33"}
            ]
        })

    # Corners & Junctions
    assets.extend([
        {
            "id": "truss_corner_2way_90",
            "name": "Truss 2-Way 90° Corner (F34)",
            "category": "Truss",
            "subcategory": "Corners & Junctions",
            "dimensions": {"x": 0.5, "y": 0.29, "z": 0.5},
            "weight_kg": 6.8,
            "mesh_generator": "gen_truss_corner_2way_90",
            "tags": ["truss", "corner", "90deg", "f34", "right angle"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [0.0, 0.0, -0.25], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.25, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_corner_2way_120",
            "name": "Truss 2-Way 120° Corner (F34)",
            "category": "Truss",
            "subcategory": "Corners & Junctions",
            "dimensions": {"x": 0.6, "y": 0.29, "z": 0.5},
            "weight_kg": 7.2,
            "mesh_generator": "gen_truss_corner_2way_angle",
            "tags": ["truss", "corner", "120deg", "f34", "hexagon"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [-0.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.25, 0.0, 0.2], "normal": [0.5, 0.0, 0.866], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_corner_2way_135",
            "name": "Truss 2-Way 135° Corner (F34)",
            "category": "Truss",
            "subcategory": "Corners & Junctions",
            "dimensions": {"x": 0.6, "y": 0.29, "z": 0.45},
            "weight_kg": 7.0,
            "mesh_generator": "gen_truss_corner_2way_angle",
            "tags": ["truss", "corner", "135deg", "f34", "octagon"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [-0.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.25, 0.0, 0.15], "normal": [0.707, 0.0, 0.707], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_junction_3way_t",
            "name": "Truss 3-Way T-Junction (F34)",
            "category": "Truss",
            "subcategory": "Corners & Junctions",
            "dimensions": {"x": 0.5, "y": 0.29, "z": 0.5},
            "weight_kg": 8.5,
            "mesh_generator": "gen_truss_junction_t",
            "tags": ["truss", "junction", "t-junction", "3way", "f34"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [-0.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.25, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, 0.25], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_junction_4way_cross",
            "name": "Truss 4-Way Cross Junction (F34)",
            "category": "Truss",
            "subcategory": "Corners & Junctions",
            "dimensions": {"x": 0.5, "y": 0.29, "z": 0.5},
            "weight_kg": 10.2,
            "mesh_generator": "gen_truss_junction_cross",
            "tags": ["truss", "cross", "4way", "junction", "f34"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [-0.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.25, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, -0.25], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, 0.25], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_box_corner_6way",
            "name": "Truss 6-Way Box Corner Block",
            "category": "Truss",
            "subcategory": "Corners & Junctions",
            "dimensions": {"x": 0.29, "y": 0.29, "z": 0.29},
            "weight_kg": 8.0,
            "mesh_generator": "gen_truss_corner_box",
            "tags": ["truss", "corner", "box", "6way", "universal", "f34"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [-0.145, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.145, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, -0.145, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.145, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, -0.145], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, 0.145], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_base_plate_small",
            "name": "Steel Base Plate 0.8x0.8m",
            "category": "Truss",
            "subcategory": "Bases & Adapters",
            "dimensions": {"x": 0.8, "y": 0.015, "z": 0.8},
            "weight_kg": 28.0,
            "mesh_generator": "gen_truss_base_plate",
            "tags": ["truss", "base", "steel", "plate", "stand"],
            "snap_points": [
                {"pos": [0.0, 0.015, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_base_plate_heavy",
            "name": "Heavy Steel Base Plate 1.0x1.0m",
            "category": "Truss",
            "subcategory": "Bases & Adapters",
            "dimensions": {"x": 1.0, "y": 0.02, "z": 1.0},
            "weight_kg": 55.0,
            "mesh_generator": "gen_truss_base_plate",
            "tags": ["truss", "base", "heavy", "ballast", "steel"],
            "snap_points": [
                {"pos": [0.0, 0.02, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.02, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "tower_mast"}
            ]
        },
        {
            "id": "truss_tower_section_2m",
            "name": "Truss Mast Tower Section 2m",
            "category": "Truss",
            "subcategory": "Tower System",
            "dimensions": {"x": 0.4, "y": 2.0, "z": 0.4},
            "weight_kg": 28.0,
            "mesh_generator": "gen_truss_tower",
            "tags": ["truss", "tower", "column", "vertical", "ground support"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [0.0, -1.0, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "tower_mast"},
                {"pos": [0.0, 1.0, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "tower_mast"}
            ]
        },
        {
            "id": "truss_tower_section_3m",
            "name": "Truss Mast Tower Section 3m",
            "category": "Truss",
            "subcategory": "Tower System",
            "dimensions": {"x": 0.4, "y": 3.0, "z": 0.4},
            "weight_kg": 39.0,
            "mesh_generator": "gen_truss_tower",
            "tags": ["truss", "tower", "column", "3m", "heavy mast"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [0.0, -1.5, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "tower_mast"},
                {"pos": [0.0, 1.5, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "tower_mast"}
            ]
        },
        {
            "id": "truss_sleeve_block",
            "name": "Truss 4-Way Sleeve Block",
            "category": "Truss",
            "subcategory": "Tower System",
            "dimensions": {"x": 0.55, "y": 0.55, "z": 0.55},
            "weight_kg": 32.0,
            "mesh_generator": "gen_truss_sleeve_block",
            "tags": ["truss", "sleeve", "roller", "tower block", "hoist"],
            "variants": truss_variants,
            "snap_points": [
                {"pos": [-0.275, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.275, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, -0.275], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, 0.275], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "truss_half_conical",
            "name": "Truss Spigot Coupler",
            "category": "Truss",
            "subcategory": "Bases & Adapters",
            "dimensions": {"x": 0.05, "y": 0.05, "z": 0.08},
            "weight_kg": 0.3,
            "mesh_generator": "gen_truss_coupler",
            "tags": ["truss", "coupler", "pin", "spigot", "conical"],
            "snap_points": [
                {"pos": [0.0, 0.0, -0.04], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, 0.04], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        }
    ])

    # -------------------------------------------------------------
    # 2. ROOF & STRUCTURE (13 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "roof_tower_ground_support_10m",
            "name": "Ground-Support Mast Tower 10m",
            "category": "Roof & Structure",
            "subcategory": "Towers",
            "dimensions": {"x": 0.8, "y": 10.0, "z": 0.8},
            "weight_kg": 320.0,
            "mesh_generator": "gen_roof_tower",
            "tags": ["roof", "tower", "ground support", "mast", "10m"],
            "snap_points": [
                {"pos": [0.0, 5.0, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "roof_corner"},
                {"pos": [0.0, -5.0, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "ground_ballast"}
            ]
        },
        {
            "id": "roof_tower_ground_support_14m",
            "name": "Ground-Support Mast Tower 14m",
            "category": "Roof & Structure",
            "subcategory": "Towers",
            "dimensions": {"x": 1.0, "y": 14.0, "z": 1.0},
            "weight_kg": 510.0,
            "mesh_generator": "gen_roof_tower",
            "tags": ["roof", "tower", "heavy mast", "14m", "stadium"],
            "snap_points": [
                {"pos": [0.0, 7.0, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "roof_corner"},
                {"pos": [0.0, -7.0, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "ground_ballast"}
            ]
        },
        {
            "id": "roof_stage_small_8x6m",
            "name": "Pitched Stage Roof Small (8x6m)",
            "category": "Roof & Structure",
            "subcategory": "Stage Roofs",
            "dimensions": {"x": 8.5, "y": 5.5, "z": 6.5},
            "weight_kg": 1850.0,
            "mesh_generator": "gen_stage_roof",
            "tags": ["roof", "canopy", "stage cover", "pitched roof", "8x6"],
            "variants": [
                {"id": "black", "name": "Black Canopy", "material": "canopy_black"},
                {"id": "white", "name": "White Canopy", "material": "canopy_white"},
                {"id": "transparent", "name": "Clear Skin", "material": "canopy_clear"}
            ],
            "snap_points": [
                {"pos": [-4.0, -2.75, -3.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [4.0, -2.75, -3.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [-4.0, -2.75, 3.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [4.0, -2.75, 3.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"}
            ]
        },
        {
            "id": "roof_stage_medium_12x10m",
            "name": "Arch Stage Roof Medium (12x10m)",
            "category": "Roof & Structure",
            "subcategory": "Stage Roofs",
            "dimensions": {"x": 12.8, "y": 7.5, "z": 10.5},
            "weight_kg": 3400.0,
            "mesh_generator": "gen_stage_roof",
            "tags": ["roof", "arch", "festival roof", "medium", "12x10"],
            "variants": [
                {"id": "black", "name": "Black Canopy", "material": "canopy_black"},
                {"id": "white", "name": "White Canopy", "material": "canopy_white"}
            ],
            "snap_points": [
                {"pos": [-6.0, -3.75, -5.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [6.0, -3.75, -5.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [-6.0, -3.75, 5.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [6.0, -3.75, 5.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"}
            ]
        },
        {
            "id": "roof_stage_large_16x12m",
            "name": "Saddle Stage Roof Large (16x12m)",
            "category": "Roof & Structure",
            "subcategory": "Stage Roofs",
            "dimensions": {"x": 17.2, "y": 9.5, "z": 13.0},
            "weight_kg": 6200.0,
            "mesh_generator": "gen_stage_roof",
            "tags": ["roof", "saddle", "large stage", "festival main stage", "16x12"],
            "variants": [
                {"id": "black", "name": "Black Canopy", "material": "canopy_black"},
                {"id": "silver", "name": "Silver/Black Canopy", "material": "canopy_silver"}
            ],
            "snap_points": [
                {"pos": [-8.0, -4.75, -6.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [8.0, -4.75, -6.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [-8.0, -4.75, 6.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"},
                {"pos": [8.0, -4.75, 6.0], "normal": [0.0, -1.0, 0.0], "tag": "roof_corner"}
            ]
        },
        {
            "id": "roof_sound_wing_left",
            "name": "PA Rigging Sound Wing Left",
            "category": "Roof & Structure",
            "subcategory": "Wings",
            "dimensions": {"x": 3.5, "y": 8.0, "z": 4.0},
            "weight_kg": 450.0,
            "mesh_generator": "gen_roof_wing",
            "tags": ["roof", "wing", "pa wing", "sound wing", "left"],
            "snap_points": [
                {"pos": [1.75, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "roof_corner"}
            ]
        },
        {
            "id": "roof_sound_wing_right",
            "name": "PA Rigging Sound Wing Right",
            "category": "Roof & Structure",
            "subcategory": "Wings",
            "dimensions": {"x": 3.5, "y": 8.0, "z": 4.0},
            "weight_kg": 450.0,
            "mesh_generator": "gen_roof_wing",
            "tags": ["roof", "wing", "pa wing", "sound wing", "right"],
            "snap_points": [
                {"pos": [-1.75, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "roof_corner"}
            ]
        },
        {
            "id": "structure_delay_tower_10m",
            "name": "Audio Delay Tower 10m",
            "category": "Roof & Structure",
            "subcategory": "Towers",
            "dimensions": {"x": 2.5, "y": 10.0, "z": 2.5},
            "weight_kg": 480.0,
            "mesh_generator": "gen_delay_tower",
            "tags": ["structure", "delay tower", "audio", "outriggers"],
            "snap_points": [
                {"pos": [0.0, 4.5, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "hoist_rig_point"}
            ]
        },
        {
            "id": "structure_foh_tent_4x3m",
            "name": "Covered FOH Control Tent 4x3m",
            "category": "Roof & Structure",
            "subcategory": "Tents",
            "dimensions": {"x": 4.0, "y": 2.8, "z": 3.0},
            "weight_kg": 160.0,
            "mesh_generator": "gen_tent_structure",
            "tags": ["structure", "tent", "foh", "booth", "canopy", "mix"],
            "snap_points": []
        },
        {
            "id": "structure_marquee_tent_6x6m",
            "name": "Hospitality Marquee Tent 6x6m",
            "category": "Roof & Structure",
            "subcategory": "Tents",
            "dimensions": {"x": 6.0, "y": 3.2, "z": 6.0},
            "weight_kg": 280.0,
            "mesh_generator": "gen_tent_structure",
            "tags": ["structure", "marquee", "gazebo", "hospitality", "tent", "catering"],
            "snap_points": []
        },
        {
            "id": "structure_scaff_standard_3m",
            "name": "Scaffolding Vertical Standard 3m",
            "category": "Roof & Structure",
            "subcategory": "Scaffolding",
            "dimensions": {"x": 0.15, "y": 3.0, "z": 0.15},
            "weight_kg": 14.5,
            "mesh_generator": "gen_scaffolding_standard",
            "tags": ["structure", "scaffolding", "layher", "tube", "standard"],
            "snap_points": [
                {"pos": [0.0, -1.5, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "scaff_rosette"},
                {"pos": [0.0, 1.5, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "scaff_rosette"}
            ]
        },
        {
            "id": "structure_scaff_bay_25m",
            "name": "Scaffolding Deck Bay 2.5x1m",
            "category": "Roof & Structure",
            "subcategory": "Scaffolding",
            "dimensions": {"x": 2.57, "y": 2.0, "z": 1.09},
            "weight_kg": 95.0,
            "mesh_generator": "gen_scaffolding_bay",
            "tags": ["structure", "scaffolding", "bay", "platform", "steel deck"],
            "snap_points": [
                {"pos": [-1.285, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "scaff_bay_side"},
                {"pos": [1.285, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "scaff_bay_side"}
            ]
        },
        {
            "id": "structure_scaff_stair_tower",
            "name": "Scaffolding Access Stair Tower",
            "category": "Roof & Structure",
            "subcategory": "Scaffolding",
            "dimensions": {"x": 2.57, "y": 3.5, "z": 1.4},
            "weight_kg": 210.0,
            "mesh_generator": "gen_scaffolding_stairs",
            "tags": ["structure", "scaffolding", "stairs", "access", "egress"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 3. RIGGING (9 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "rigging_chain_hoist_05t",
            "name": "Electric Chain Hoist 0.5t (D8+)",
            "category": "Rigging",
            "subcategory": "Motors",
            "dimensions": {"x": 0.35, "y": 0.5, "z": 0.28},
            "weight_kg": 32.0,
            "mesh_generator": "gen_chain_hoist",
            "tags": ["rigging", "hoist", "motor", "d8", "0.5t", "chain"],
            "snap_points": [
                {"pos": [0.0, 0.25, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "hoist_top_hook"},
                {"pos": [0.0, -0.25, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "hoist_bottom_hook"}
            ]
        },
        {
            "id": "rigging_chain_hoist_1t",
            "name": "Electric Chain Hoist 1.0t (D8+)",
            "category": "Rigging",
            "subcategory": "Motors",
            "dimensions": {"x": 0.42, "y": 0.65, "z": 0.32},
            "weight_kg": 58.0,
            "mesh_generator": "gen_chain_hoist",
            "tags": ["rigging", "hoist", "motor", "1t", "d8", "touring"],
            "snap_points": [
                {"pos": [0.0, 0.325, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "hoist_top_hook"},
                {"pos": [0.0, -0.325, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "hoist_bottom_hook"}
            ]
        },
        {
            "id": "rigging_chain_hoist_2t",
            "name": "Electric Chain Hoist 2.0t (BGV-C1)",
            "category": "Rigging",
            "subcategory": "Motors",
            "dimensions": {"x": 0.52, "y": 0.8, "z": 0.4},
            "weight_kg": 110.0,
            "mesh_generator": "gen_chain_hoist",
            "tags": ["rigging", "hoist", "motor", "2t", "bgv-c1", "heavy lift"],
            "snap_points": [
                {"pos": [0.0, 0.4, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "hoist_top_hook"},
                {"pos": [0.0, -0.4, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "hoist_bottom_hook"}
            ]
        },
        {
            "id": "rigging_motor_controller_4ch",
            "name": "4-Channel Hoist Motor Controller",
            "category": "Rigging",
            "subcategory": "Control",
            "dimensions": {"x": 0.55, "y": 0.45, "z": 0.5},
            "weight_kg": 28.0,
            "mesh_generator": "gen_flight_case_rack",
            "tags": ["rigging", "motor", "controller", "cee", "pendant"],
            "snap_points": []
        },
        {
            "id": "rigging_shackle_325t",
            "name": "Safety Bow Shackle 3.25t",
            "category": "Rigging",
            "subcategory": "Hardware",
            "dimensions": {"x": 0.08, "y": 0.12, "z": 0.04},
            "weight_kg": 0.65,
            "mesh_generator": "gen_rigging_shackle",
            "tags": ["rigging", "shackle", "bow shackle", "green pin", "steel"],
            "snap_points": [
                {"pos": [0.0, -0.06, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "shackle_eye"}
            ]
        },
        {
            "id": "rigging_shackle_475t",
            "name": "Safety Bow Shackle 4.75t",
            "category": "Rigging",
            "subcategory": "Hardware",
            "dimensions": {"x": 0.1, "y": 0.15, "z": 0.05},
            "weight_kg": 1.1,
            "mesh_generator": "gen_rigging_shackle",
            "tags": ["rigging", "shackle", "heavy", "4.75t", "hardware"],
            "snap_points": [
                {"pos": [0.0, -0.075, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "shackle_eye"}
            ]
        },
        {
            "id": "rigging_spanset_2m",
            "name": "Round Sling Spanset 2m (2t WLL)",
            "category": "Rigging",
            "subcategory": "Slings",
            "dimensions": {"x": 0.08, "y": 2.0, "z": 0.04},
            "weight_kg": 1.8,
            "mesh_generator": "gen_rigging_sling",
            "tags": ["rigging", "spanset", "sling", "strap", "choke"],
            "snap_points": []
        },
        {
            "id": "rigging_beam_clamp_3t",
            "name": "Adjustable Girder Beam Clamp 3t",
            "category": "Rigging",
            "subcategory": "Hardware",
            "dimensions": {"x": 0.35, "y": 0.25, "z": 0.18},
            "weight_kg": 9.5,
            "mesh_generator": "gen_rigging_clamp",
            "tags": ["rigging", "clamp", "beam clamp", "girder", "anchor point"],
            "snap_points": [
                {"pos": [0.0, -0.125, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "hoist_top_hook"}
            ]
        },
        {
            "id": "rigging_safety_bond_1m",
            "name": "Steel Wire Safety Cable 1m (50kg)",
            "category": "Rigging",
            "subcategory": "Hardware",
            "dimensions": {"x": 0.02, "y": 1.0, "z": 0.02},
            "weight_kg": 0.4,
            "mesh_generator": "gen_rigging_safety_cable",
            "tags": ["rigging", "safety", "cable", "bond", "carabiner"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 4. STAGING (16 items)
    # -------------------------------------------------------------
    deck_variants = [
        {"id": "black", "name": "Phenolic Black Plywood", "material": "stage_black_deck"},
        {"id": "natural", "name": "Natural Wood Plywood", "material": "wood_natural"},
        {"id": "grate", "name": "Heavy Aluminum Grate", "material": "aluminum_grate"}
    ]

    assets.extend([
        {
            "id": "staging_deck_2x1m",
            "name": "Pro Stage Deck 2.0x1.0m",
            "category": "Staging",
            "subcategory": "Decks",
            "dimensions": {"x": 2.0, "y": 0.4, "z": 1.0},
            "weight_kg": 32.0,
            "mesh_generator": "gen_stage_deck",
            "tags": ["staging", "deck", "platform", "riser", "2x1"],
            "variants": deck_variants,
            "snap_points": [
                {"pos": [-1.0, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "deck_edge_1m"},
                {"pos": [1.0, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "deck_edge_1m"},
                {"pos": [0.0, 0.0, -0.5], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_2m"},
                {"pos": [0.0, 0.0, 0.5], "normal": [0.0, 0.0, 1.0], "tag": "deck_edge_2m"}
            ]
        },
        {
            "id": "staging_deck_1x1m",
            "name": "Stage Deck 1.0x1.0m",
            "category": "Staging",
            "subcategory": "Decks",
            "dimensions": {"x": 1.0, "y": 0.4, "z": 1.0},
            "weight_kg": 18.0,
            "mesh_generator": "gen_stage_deck",
            "tags": ["staging", "deck", "compact", "platform", "1x1"],
            "variants": deck_variants,
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "deck_edge_1m"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "deck_edge_1m"},
                {"pos": [0.0, 0.0, -0.5], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"},
                {"pos": [0.0, 0.0, 0.5], "normal": [0.0, 0.0, 1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_deck_2x2m",
            "name": "Large Stage Deck 2.0x2.0m",
            "category": "Staging",
            "subcategory": "Decks",
            "dimensions": {"x": 2.0, "y": 0.4, "z": 2.0},
            "weight_kg": 62.0,
            "mesh_generator": "gen_stage_deck",
            "tags": ["staging", "deck", "large", "riser", "2x2"],
            "variants": deck_variants,
            "snap_points": [
                {"pos": [-1.0, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "deck_edge_2m"},
                {"pos": [1.0, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "deck_edge_2m"},
                {"pos": [0.0, 0.0, -1.0], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_2m"},
                {"pos": [0.0, 0.0, 1.0], "normal": [0.0, 0.0, 1.0], "tag": "deck_edge_2m"}
            ]
        },
        {
            "id": "staging_deck_1x05m",
            "name": "Half-Width Stage Deck 1.0x0.5m",
            "category": "Staging",
            "subcategory": "Decks",
            "dimensions": {"x": 1.0, "y": 0.4, "z": 0.5},
            "weight_kg": 11.5,
            "mesh_generator": "gen_stage_deck",
            "tags": ["staging", "deck", "half", "filler", "1x0.5"],
            "variants": deck_variants,
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "deck_edge_half"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "deck_edge_half"},
                {"pos": [0.0, 0.0, -0.25], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"},
                {"pos": [0.0, 0.0, 0.25], "normal": [0.0, 0.0, 1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_deck_tri_1m",
            "name": "Triangular Corner Deck 1.0x1.0m",
            "category": "Staging",
            "subcategory": "Decks",
            "dimensions": {"x": 1.0, "y": 0.4, "z": 1.0},
            "weight_kg": 12.0,
            "mesh_generator": "gen_stage_deck_tri",
            "tags": ["staging", "deck", "triangle", "corner deck"],
            "variants": deck_variants,
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "deck_edge_1m"},
                {"pos": [0.0, 0.0, -0.5], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_deck_circular_wedge",
            "name": "Circular Wedge Stage Segment R2m",
            "category": "Staging",
            "subcategory": "Decks",
            "dimensions": {"x": 1.5, "y": 0.4, "z": 1.0},
            "weight_kg": 22.0,
            "mesh_generator": "gen_stage_deck_wedge",
            "tags": ["staging", "circular", "round stage", "wedge", "curved deck"],
            "variants": deck_variants,
            "snap_points": []
        },
        {
            "id": "staging_riser_drum_rolling",
            "name": "Rolling Drum Riser 2.0x2.0m",
            "category": "Staging",
            "subcategory": "Risers",
            "dimensions": {"x": 2.0, "y": 0.55, "z": 2.0},
            "weight_kg": 78.0,
            "mesh_generator": "gen_stage_deck_rolling",
            "tags": ["staging", "riser", "drum riser", "rolling", "wheels", "casters"],
            "snap_points": []
        },
        {
            "id": "staging_riser_dj_2x1m",
            "name": "Elevated DJ Riser 2.0x1.0m",
            "category": "Staging",
            "subcategory": "Risers",
            "dimensions": {"x": 2.0, "y": 0.9, "z": 1.0},
            "weight_kg": 45.0,
            "mesh_generator": "gen_stage_deck",
            "tags": ["staging", "dj", "riser", "platform", "tall deck"],
            "snap_points": []
        },
        {
            "id": "staging_riser_foh_platform",
            "name": "Elevated FOH Platform 4.0x3.0m",
            "category": "Staging",
            "subcategory": "Risers",
            "dimensions": {"x": 4.0, "y": 0.6, "z": 3.0},
            "weight_kg": 240.0,
            "mesh_generator": "gen_stage_platform_large",
            "tags": ["staging", "foh", "platform", "mix riser", "heavy deck"],
            "snap_points": []
        },
        {
            "id": "staging_skirting_black_2m",
            "name": "Pleated Black Stage Skirt 2m",
            "category": "Staging",
            "subcategory": "Accessories",
            "dimensions": {"x": 2.0, "y": 0.6, "z": 0.02},
            "weight_kg": 1.2,
            "mesh_generator": "gen_stage_skirt",
            "tags": ["staging", "skirt", "black skirt", "velcro", "fabric"],
            "snap_points": [
                {"pos": [0.0, 0.3, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "deck_edge_2m"}
            ]
        },
        {
            "id": "staging_ramp_wheelchair_4m",
            "name": "Modular Equipment / ADA Ramp 4m",
            "category": "Staging",
            "subcategory": "Access",
            "dimensions": {"x": 1.2, "y": 0.6, "z": 4.0},
            "weight_kg": 115.0,
            "mesh_generator": "gen_stage_ramp",
            "tags": ["staging", "ramp", "wheelchair", "ada", "loading ramp"],
            "snap_points": [
                {"pos": [0.0, 0.3, -2.0], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_stairs_2step",
            "name": "Modular 2-Step Stage Stairs (0.4m)",
            "category": "Staging",
            "subcategory": "Access",
            "dimensions": {"x": 1.0, "y": 0.4, "z": 0.6},
            "weight_kg": 14.0,
            "mesh_generator": "gen_stage_stairs",
            "tags": ["staging", "stairs", "steps", "2-step", "0.4m"],
            "snap_points": [
                {"pos": [0.0, 0.2, -0.3], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_stairs_4step",
            "name": "Modular 4-Step Stage Stairs (0.8m)",
            "category": "Staging",
            "subcategory": "Access",
            "dimensions": {"x": 1.0, "y": 0.8, "z": 1.2},
            "weight_kg": 25.0,
            "mesh_generator": "gen_stage_stairs",
            "tags": ["staging", "stairs", "steps", "4-step", "0.8m"],
            "snap_points": [
                {"pos": [0.0, 0.4, -0.6], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_stairs_6step",
            "name": "Modular 6-Step Stairs with Rail (1.2m)",
            "category": "Staging",
            "subcategory": "Access",
            "dimensions": {"x": 1.0, "y": 2.2, "z": 1.8},
            "weight_kg": 52.0,
            "mesh_generator": "gen_stage_stairs_railed",
            "tags": ["staging", "stairs", "handrail", "6-step", "1.2m high"],
            "snap_points": [
                {"pos": [0.0, 0.6, -0.9], "normal": [0.0, 0.0, -1.0], "tag": "deck_edge_1m"}
            ]
        },
        {
            "id": "staging_barricade_straight",
            "name": "Mojo Crowd Barrier Straight 1m",
            "category": "Staging",
            "subcategory": "Crowd Barriers",
            "dimensions": {"x": 1.0, "y": 1.2, "z": 0.8},
            "weight_kg": 35.0,
            "mesh_generator": "gen_crowd_barrier",
            "tags": ["staging", "barrier", "mojo", "pit barrier", "crowd control"],
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "barrier_side"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "barrier_side"}
            ]
        },
        {
            "id": "staging_barricade_corner_90",
            "name": "Mojo Crowd Barrier 90° Corner",
            "category": "Staging",
            "subcategory": "Crowd Barriers",
            "dimensions": {"x": 0.8, "y": 1.2, "z": 0.8},
            "weight_kg": 32.0,
            "mesh_generator": "gen_crowd_barrier_corner",
            "tags": ["staging", "barrier", "corner", "90deg", "pit"],
            "snap_points": [
                {"pos": [-0.4, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "barrier_side"},
                {"pos": [0.0, 0.0, 0.4], "normal": [0.0, 0.0, 1.0], "tag": "barrier_side"}
            ]
        },
        {
            "id": "staging_barricade_cable_gate",
            "name": "Mojo Barrier Cable Pass-Through Gate",
            "category": "Staging",
            "subcategory": "Crowd Barriers",
            "dimensions": {"x": 1.0, "y": 1.2, "z": 0.8},
            "weight_kg": 38.0,
            "mesh_generator": "gen_crowd_barrier_gate",
            "tags": ["staging", "barrier", "gate", "cable pass", "mojo"],
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "barrier_side"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "barrier_side"}
            ]
        }
    ])

    # -------------------------------------------------------------
    # 5. AUDIO (18 items)
    # -------------------------------------------------------------
    case_variants = [
        {"id": "black", "name": "Stealth Black", "material": "flight_case_black"},
        {"id": "blue", "name": "Touring Blue", "material": "flight_case_blue"},
        {"id": "red", "name": "Safety Red", "material": "flight_case_red"}
    ]

    assets.extend([
        {
            "id": "audio_array_compact_8in",
            "name": "Compact Line Array Module (Dual 8\")",
            "category": "Audio",
            "subcategory": "Line Arrays",
            "dimensions": {"x": 0.72, "y": 0.26, "z": 0.45},
            "weight_kg": 21.0,
            "mesh_generator": "gen_audio_line_array",
            "tags": ["audio", "speaker", "line array", "compact", "8-inch", "theatre"],
            "snap_points": [
                {"pos": [0.0, 0.13, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "array_pin_8"},
                {"pos": [0.0, -0.13, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "array_pin_8"}
            ]
        },
        {
            "id": "audio_array_standard_10in",
            "name": "Touring Line Array Module (Dual 10\")",
            "category": "Audio",
            "subcategory": "Line Arrays",
            "dimensions": {"x": 1.0, "y": 0.35, "z": 0.5},
            "weight_kg": 42.0,
            "mesh_generator": "gen_audio_line_array",
            "tags": ["audio", "speaker", "pa", "line array", "10-inch", "touring"],
            "snap_points": [
                {"pos": [0.0, 0.175, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "array_pin_10"},
                {"pos": [0.0, -0.175, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "array_pin_10"}
            ]
        },
        {
            "id": "audio_array_stadium_15in",
            "name": "Stadium Large Line Array (Dual 15\")",
            "category": "Audio",
            "subcategory": "Line Arrays",
            "dimensions": {"x": 1.25, "y": 0.48, "z": 0.65},
            "weight_kg": 72.0,
            "mesh_generator": "gen_audio_line_array",
            "tags": ["audio", "speaker", "stadium array", "large pa", "festival main hang"],
            "snap_points": [
                {"pos": [0.0, 0.24, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "array_pin_15"},
                {"pos": [0.0, -0.24, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "array_pin_15"}
            ]
        },
        {
            "id": "audio_sub_single_18in",
            "name": "Single 18\" Touring Subwoofer",
            "category": "Audio",
            "subcategory": "Subwoofers",
            "dimensions": {"x": 0.75, "y": 0.55, "z": 0.75},
            "weight_kg": 48.0,
            "mesh_generator": "gen_audio_sub_single",
            "tags": ["audio", "sub", "bass", "18-inch", "single sub"],
            "snap_points": [
                {"pos": [0.0, 0.275, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "sub_pole_mount"}
            ]
        },
        {
            "id": "audio_sub_dual_18in",
            "name": "Dual 18\" Reflex Subwoofer",
            "category": "Audio",
            "subcategory": "Subwoofers",
            "dimensions": {"x": 1.2, "y": 0.6, "z": 0.8},
            "weight_kg": 85.0,
            "mesh_generator": "gen_audio_subwoofer",
            "tags": ["audio", "sub", "dual 18", "bass", "ground stack"],
            "snap_points": [
                {"pos": [0.0, 0.3, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "sub_stack"},
                {"pos": [0.0, -0.3, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "sub_stack"},
                {"pos": [-0.6, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "sub_side"},
                {"pos": [0.6, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "sub_side"}
            ]
        },
        {
            "id": "audio_sub_cardioid_stack",
            "name": "Cardioid 3-Sub Column Stack",
            "category": "Audio",
            "subcategory": "Subwoofers",
            "dimensions": {"x": 1.2, "y": 1.8, "z": 0.8},
            "weight_kg": 255.0,
            "mesh_generator": "gen_audio_sub_cardioid",
            "tags": ["audio", "subwoofer", "cardioid", "sub array", "bass stack"],
            "snap_points": [
                {"pos": [-0.6, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "sub_side"},
                {"pos": [0.6, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "sub_side"}
            ]
        },
        {
            "id": "audio_speaker_frontfill",
            "name": "Coaxial Stage Frontfill Speaker",
            "category": "Audio",
            "subcategory": "Fills & Monitors",
            "dimensions": {"x": 0.45, "y": 0.2, "z": 0.25},
            "weight_kg": 9.5,
            "mesh_generator": "gen_audio_frontfill",
            "tags": ["audio", "frontfill", "lip fill", "nearfield", "stage lip"],
            "snap_points": []
        },
        {
            "id": "audio_delay_stack_pole",
            "name": "Pole-Mounted Delay Stack on Sub",
            "category": "Audio",
            "subcategory": "Fills & Monitors",
            "dimensions": {"x": 0.6, "y": 2.1, "z": 0.6},
            "weight_kg": 46.0,
            "mesh_generator": "gen_audio_pole_stack",
            "tags": ["audio", "delay", "speaker stand", "pole mount", "sub satellite"],
            "snap_points": []
        },
        {
            "id": "audio_wedge_monitor_12in",
            "name": "Low-Profile 12\" Stage Wedge",
            "category": "Audio",
            "subcategory": "Fills & Monitors",
            "dimensions": {"x": 0.5, "y": 0.3, "z": 0.4},
            "weight_kg": 16.0,
            "mesh_generator": "gen_audio_monitor",
            "tags": ["audio", "wedge", "foldback", "monitor", "12-inch"],
            "snap_points": []
        },
        {
            "id": "audio_wedge_monitor_15in",
            "name": "High-Output 15\" Stage Wedge",
            "category": "Audio",
            "subcategory": "Fills & Monitors",
            "dimensions": {"x": 0.6, "y": 0.38, "z": 0.48},
            "weight_kg": 24.0,
            "mesh_generator": "gen_audio_monitor",
            "tags": ["audio", "wedge", "15-inch", "heavy monitor", "vocal wedge"],
            "snap_points": []
        },
        {
            "id": "audio_sidefill_system",
            "name": "3-Way Active Sidefill System",
            "category": "Audio",
            "subcategory": "Fills & Monitors",
            "dimensions": {"x": 0.7, "y": 1.7, "z": 0.65},
            "weight_kg": 92.0,
            "mesh_generator": "gen_audio_sidefill",
            "tags": ["audio", "sidefill", "dancefill", "stage fill", "high power"],
            "snap_points": []
        },
        {
            "id": "audio_console_foh_compact",
            "name": "Compact 32-Channel FOH Console",
            "category": "Audio",
            "subcategory": "Consoles & Racks",
            "dimensions": {"x": 0.85, "y": 0.3, "z": 0.7},
            "weight_kg": 26.0,
            "mesh_generator": "gen_audio_foh",
            "tags": ["audio", "mixer", "console", "desk", "32ch", "digital"],
            "snap_points": []
        },
        {
            "id": "audio_console_foh_large",
            "name": "Touring Flagship 64ch FOH Console",
            "category": "Audio",
            "subcategory": "Consoles & Racks",
            "dimensions": {"x": 1.35, "y": 0.45, "z": 0.9},
            "weight_kg": 65.0,
            "mesh_generator": "gen_audio_foh",
            "tags": ["audio", "foh", "mixer", "64ch", "flagship desk", "multitouch"],
            "snap_points": []
        },
        {
            "id": "audio_console_monitor",
            "name": "Dedicated Stage Monitor Console",
            "category": "Audio",
            "subcategory": "Consoles & Racks",
            "dimensions": {"x": 1.2, "y": 0.45, "z": 0.85},
            "weight_kg": 58.0,
            "mesh_generator": "gen_audio_foh",
            "tags": ["audio", "monitor desk", "mixer", "iem control"],
            "snap_points": []
        },
        {
            "id": "audio_stagebox_digital_32ch",
            "name": "32-in/16-out Digital Stage Box",
            "category": "Audio",
            "subcategory": "Consoles & Racks",
            "dimensions": {"x": 0.48, "y": 0.22, "z": 0.25},
            "weight_kg": 8.5,
            "mesh_generator": "gen_flight_case_rack",
            "tags": ["audio", "stagebox", "snake", "digital snake", "xlr bay"],
            "snap_points": []
        },
        {
            "id": "audio_amprack_touring_12u",
            "name": "12U Shock-Mount Touring Amp Rack",
            "category": "Audio",
            "subcategory": "Consoles & Racks",
            "dimensions": {"x": 0.6, "y": 0.9, "z": 0.7},
            "weight_kg": 82.0,
            "mesh_generator": "gen_flight_case_rack",
            "tags": ["audio", "rack", "amps", "dsp", "flightcase", "12u"],
            "variants": case_variants,
            "snap_points": [
                {"pos": [0.0, 0.45, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "rack_stack"}
            ]
        },
        {
            "id": "audio_mic_stand_boom",
            "name": "Tripod Boom Microphone Stand",
            "category": "Audio",
            "subcategory": "Accessories",
            "dimensions": {"x": 0.6, "y": 1.5, "z": 0.6},
            "weight_kg": 3.2,
            "mesh_generator": "gen_mic_stand",
            "tags": ["audio", "mic stand", "boom", "vocal stand", "tripod"],
            "snap_points": []
        },
        {
            "id": "audio_cable_ramp_5channel",
            "name": "Heavy-Duty 5-Channel Cable Ramp 1m",
            "category": "Audio",
            "subcategory": "Accessories",
            "dimensions": {"x": 1.0, "y": 0.05, "z": 0.5},
            "weight_kg": 15.0,
            "mesh_generator": "gen_cable_ramp",
            "tags": ["audio", "cable ramp", "yellow jacket", "cable crossover", "protector"],
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "cable_ramp_link"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "cable_ramp_link"}
            ]
        }
    ])

    # -------------------------------------------------------------
    # 6. LIGHTING (14 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "lighting_moving_beam",
            "name": "Intense Beam Moving Head (Sharpy-Style)",
            "category": "Lighting",
            "subcategory": "Moving Heads",
            "dimensions": {"x": 0.38, "y": 0.58, "z": 0.35},
            "weight_kg": 18.0,
            "mesh_generator": "gen_lighting_moving_head",
            "tags": ["lighting", "beam", "moving head", "dmx", "fast optics"],
            "snap_points": [
                {"pos": [0.0, 0.29, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_moving_spot",
            "name": "High-Power LED Spot Profile",
            "category": "Lighting",
            "subcategory": "Moving Heads",
            "dimensions": {"x": 0.45, "y": 0.72, "z": 0.4},
            "weight_kg": 26.0,
            "mesh_generator": "gen_lighting_moving_head",
            "tags": ["lighting", "spot", "profile", "moving head", "gobo"],
            "snap_points": [
                {"pos": [0.0, 0.36, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_moving_wash",
            "name": "Zoom LED Wash Moving Head",
            "category": "Lighting",
            "subcategory": "Moving Heads",
            "dimensions": {"x": 0.42, "y": 0.62, "z": 0.38},
            "weight_kg": 21.0,
            "mesh_generator": "gen_lighting_moving_head",
            "tags": ["lighting", "wash", "moving head", "rgbw", "smooth zoom"],
            "snap_points": [
                {"pos": [0.0, 0.31, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_par_touring_led",
            "name": "Touring RGBW LED PAR Can",
            "category": "Lighting",
            "subcategory": "Static Fixtures",
            "dimensions": {"x": 0.28, "y": 0.35, "z": 0.28},
            "weight_kg": 4.5,
            "mesh_generator": "gen_lighting_par",
            "tags": ["lighting", "par", "par can", "rgbw", "led", "wash"],
            "snap_points": [
                {"pos": [0.0, 0.175, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_bar_pixel_1m",
            "name": "1m Pixel Batten LED Bar",
            "category": "Lighting",
            "subcategory": "Static Fixtures",
            "dimensions": {"x": 1.0, "y": 0.12, "z": 0.15},
            "weight_kg": 6.2,
            "mesh_generator": "gen_lighting_bar",
            "tags": ["lighting", "bar", "batten", "pixel", "linear", "chase"],
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "batten_link"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "batten_link"}
            ]
        },
        {
            "id": "lighting_strobe_atomic_led",
            "name": "High-Output Arena LED Strobe",
            "category": "Lighting",
            "subcategory": "Strobes & Blinders",
            "dimensions": {"x": 0.48, "y": 0.28, "z": 0.16},
            "weight_kg": 8.5,
            "mesh_generator": "gen_lighting_strobe",
            "tags": ["lighting", "strobe", "atomic", "flash", "wash panel"],
            "snap_points": [
                {"pos": [0.0, 0.14, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_blinder_2lite",
            "name": "2-Lite Molefay Audience Blinder",
            "category": "Lighting",
            "subcategory": "Strobes & Blinders",
            "dimensions": {"x": 0.42, "y": 0.25, "z": 0.15},
            "weight_kg": 4.8,
            "mesh_generator": "gen_lighting_blinder",
            "tags": ["lighting", "blinder", "molefay", "2-lite", "warm white"],
            "snap_points": [
                {"pos": [0.0, 0.125, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_blinder_4lite",
            "name": "4-Lite Matrix Crowd Blinder",
            "category": "Lighting",
            "subcategory": "Strobes & Blinders",
            "dimensions": {"x": 0.45, "y": 0.45, "z": 0.15},
            "weight_kg": 8.2,
            "mesh_generator": "gen_lighting_blinder",
            "tags": ["lighting", "blinder", "4-lite", "audience", "dwe"],
            "snap_points": [
                {"pos": [0.0, 0.225, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "truss_clamp"}
            ]
        },
        {
            "id": "lighting_followspot_stand",
            "name": "Touring Followspot on Stand",
            "category": "Lighting",
            "subcategory": "Specialty",
            "dimensions": {"x": 0.8, "y": 1.6, "z": 1.4},
            "weight_kg": 45.0,
            "mesh_generator": "gen_lighting_followspot",
            "tags": ["lighting", "followspot", "spotlight", "operator", "long throw"],
            "snap_points": []
        },
        {
            "id": "lighting_console_touring",
            "name": "Dual-Screen Grand Lighting Console",
            "category": "Lighting",
            "subcategory": "Control",
            "dimensions": {"x": 1.25, "y": 0.45, "z": 0.8},
            "weight_kg": 42.0,
            "mesh_generator": "gen_lighting_console",
            "tags": ["lighting", "console", "grandma", "desk", "dmx controller"],
            "snap_points": []
        },
        {
            "id": "lighting_console_compact",
            "name": "Compact Lighting Wing Console",
            "category": "Lighting",
            "subcategory": "Control",
            "dimensions": {"x": 0.65, "y": 0.2, "z": 0.45},
            "weight_kg": 12.0,
            "mesh_generator": "gen_lighting_console",
            "tags": ["lighting", "wing", "compact desk", "programmer", "usb"],
            "snap_points": []
        },
        {
            "id": "lighting_prerig_truss_3m",
            "name": "3m Pre-Rig Drop Truss Section",
            "category": "Lighting",
            "subcategory": "Trussing",
            "dimensions": {"x": 0.6, "y": 0.6, "z": 3.0},
            "weight_kg": 48.0,
            "mesh_generator": "gen_lighting_prerig_truss",
            "tags": ["lighting", "prerig", "hud truss", "drop frame", "fast rig"],
            "snap_points": [
                {"pos": [0.0, 0.0, -1.5], "normal": [0.0, 0.0, -1.0], "tag": "truss_f34"},
                {"pos": [0.0, 0.0, 1.5], "normal": [0.0, 0.0, 1.0], "tag": "truss_f34"}
            ]
        },
        {
            "id": "lighting_hazer_touring",
            "name": "Continuous Touring Hazer (Water-Based)",
            "category": "Lighting",
            "subcategory": "Atmospherics",
            "dimensions": {"x": 0.6, "y": 0.5, "z": 0.45},
            "weight_kg": 28.0,
            "mesh_generator": "gen_flight_case_rack",
            "tags": ["lighting", "hazer", "smoke", "fog", "atmosphere", "beams"],
            "snap_points": []
        },
        {
            "id": "lighting_fog_machine_heavy",
            "name": "Heavy High-Output Arena Fogger",
            "category": "Lighting",
            "subcategory": "Atmospherics",
            "dimensions": {"x": 0.7, "y": 0.4, "z": 0.4},
            "weight_kg": 22.0,
            "mesh_generator": "gen_fog_machine",
            "tags": ["lighting", "fog", "smoke", "burst", "pyro effect"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 7. VIDEO (10 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "video_led_panel_05m",
            "name": "Modular LED Tile 0.5x0.5m (Indoor 2.6mm)",
            "category": "Video",
            "subcategory": "LED Panels",
            "dimensions": {"x": 0.5, "y": 0.5, "z": 0.08},
            "weight_kg": 7.5,
            "mesh_generator": "gen_video_led_panel",
            "tags": ["video", "led", "wall", "screen", "panel", "0.5m", "hi-res"],
            "snap_points": [
                {"pos": [-0.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "led_wall_50"},
                {"pos": [0.25, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "led_wall_50"},
                {"pos": [0.0, -0.25, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "led_wall_50"},
                {"pos": [0.0, 0.25, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "led_wall_50"}
            ]
        },
        {
            "id": "video_led_panel_1m_high",
            "name": "Outdoor LED Tile 0.5x1.0m (IP65)",
            "category": "Video",
            "subcategory": "LED Panels",
            "dimensions": {"x": 0.5, "y": 1.0, "z": 0.09},
            "weight_kg": 13.5,
            "mesh_generator": "gen_video_led_panel",
            "tags": ["video", "led", "outdoor", "bright", "tall tile", "ip65"],
            "snap_points": [
                {"pos": [-0.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "led_wall_50"},
                {"pos": [0.25, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "led_wall_50"},
                {"pos": [0.0, -0.5, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "led_wall_50"},
                {"pos": [0.0, 0.5, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "led_wall_50"}
            ]
        },
        {
            "id": "video_led_mesh_1x1m",
            "name": "Semi-Transparent LED Mesh 1.0x1.0m",
            "category": "Video",
            "subcategory": "LED Panels",
            "dimensions": {"x": 1.0, "y": 1.0, "z": 0.06},
            "weight_kg": 11.0,
            "mesh_generator": "gen_video_led_mesh",
            "tags": ["video", "mesh", "transparent", "blow-through", "wind load"],
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "led_mesh_1m"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "led_mesh_1m"},
                {"pos": [0.0, -0.5, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "led_mesh_1m"},
                {"pos": [0.0, 0.5, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "led_mesh_1m"}
            ]
        },
        {
            "id": "video_led_ground_stack_frame",
            "name": "LED Wall Ground-Support Frame 3.5m",
            "category": "Video",
            "subcategory": "Rigging & Support",
            "dimensions": {"x": 1.0, "y": 3.5, "z": 1.2},
            "weight_kg": 85.0,
            "mesh_generator": "gen_video_led_stack_frame",
            "tags": ["video", "frame", "ground support", "led ballast", "spine"],
            "snap_points": [
                {"pos": [0.0, 0.0, 0.0], "normal": [0.0, 0.0, 1.0], "tag": "led_wall_50"}
            ]
        },
        {
            "id": "video_screen_fastfold_16x9",
            "name": "16:9 Fast-Fold Screen (6.0x3.4m)",
            "category": "Video",
            "subcategory": "Projection",
            "dimensions": {"x": 6.2, "y": 4.5, "z": 1.5},
            "weight_kg": 95.0,
            "mesh_generator": "gen_video_fastfold_screen",
            "tags": ["video", "projection", "screen", "fastfold", "16:9", "legs"],
            "snap_points": []
        },
        {
            "id": "video_projector_laser_20k",
            "name": "20K Lumen Laser Venue Projector",
            "category": "Video",
            "subcategory": "Projection",
            "dimensions": {"x": 0.75, "y": 0.35, "z": 0.65},
            "weight_kg": 48.0,
            "mesh_generator": "gen_video_projector",
            "tags": ["video", "projector", "laser", "20000 lumens", "4k"],
            "snap_points": []
        },
        {
            "id": "video_control_rack_flightcase",
            "name": "Video Switcher & Media Server Rack",
            "category": "Video",
            "subcategory": "Control",
            "dimensions": {"x": 0.6, "y": 1.1, "z": 0.75},
            "weight_kg": 95.0,
            "mesh_generator": "gen_flight_case_rack",
            "tags": ["video", "switcher", "media server", "disguise", "rack"],
            "variants": case_variants,
            "snap_points": []
        },
        {
            "id": "video_camera_tripod_pedestal",
            "name": "Broadcast 4K Camera on Heavy Tripod",
            "category": "Video",
            "subcategory": "Cameras",
            "dimensions": {"x": 0.9, "y": 1.7, "z": 0.9},
            "weight_kg": 28.0,
            "mesh_generator": "gen_video_camera_tripod",
            "tags": ["video", "camera", "tripod", "broadcast", "operator"],
            "snap_points": []
        },
        {
            "id": "video_camera_jib_crane_6m",
            "name": "6m Motorized Camera Jib Crane",
            "category": "Video",
            "subcategory": "Cameras",
            "dimensions": {"x": 1.5, "y": 3.5, "z": 6.5},
            "weight_kg": 145.0,
            "mesh_generator": "gen_video_camera_crane",
            "tags": ["video", "crane", "jib", "camera boom", "sweeping shots"],
            "snap_points": []
        },
        {
            "id": "video_confidence_monitor_55in",
            "name": "55\" Stage Confidence Teleprompter Wedge",
            "category": "Video",
            "subcategory": "Displays",
            "dimensions": {"x": 1.25, "y": 0.45, "z": 0.55},
            "weight_kg": 26.0,
            "mesh_generator": "gen_audio_monitor",
            "tags": ["video", "prompter", "confidence monitor", "lcd wedge"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 8. POWER & INFRASTRUCTURE (10 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "power_distro_32a",
            "name": "Portable 32A 3-Phase Stage Distro",
            "category": "Power",
            "subcategory": "Distribution",
            "dimensions": {"x": 0.45, "y": 0.35, "z": 0.35},
            "weight_kg": 16.0,
            "mesh_generator": "gen_power_distro",
            "tags": ["power", "distro", "32a", "stage box", "cee"],
            "snap_points": []
        },
        {
            "id": "power_distro_63a",
            "name": "63A 3-Phase Touring Distro Rack",
            "category": "Power",
            "subcategory": "Distribution",
            "dimensions": {"x": 0.6, "y": 0.85, "z": 0.6},
            "weight_kg": 55.0,
            "mesh_generator": "gen_power_distro",
            "tags": ["power", "distro", "63a", "rubber rack", "touring"],
            "snap_points": []
        },
        {
            "id": "power_distro_125a_master",
            "name": "125A Master Mains Touring Distro",
            "category": "Power",
            "subcategory": "Distribution",
            "dimensions": {"x": 0.8, "y": 1.2, "z": 0.7},
            "weight_kg": 110.0,
            "mesh_generator": "gen_power_distro",
            "tags": ["power", "distro", "125a", "master", "mains", "camlock"],
            "snap_points": []
        },
        {
            "id": "power_generator_small_30kva",
            "name": "Silenced Mobile Generator 30 kVA",
            "category": "Power",
            "subcategory": "Generators",
            "dimensions": {"x": 1.8, "y": 1.2, "z": 0.9},
            "weight_kg": 850.0,
            "mesh_generator": "gen_generator",
            "tags": ["power", "generator", "diesel", "30kva", "silenced"],
            "snap_points": []
        },
        {
            "id": "power_generator_medium_100kva",
            "name": "Towable Road Generator 100 kVA",
            "category": "Power",
            "subcategory": "Generators",
            "dimensions": {"x": 3.2, "y": 1.8, "z": 1.4},
            "weight_kg": 2100.0,
            "mesh_generator": "gen_generator",
            "tags": ["power", "generator", "trailer", "100kva", "event mains"],
            "snap_points": []
        },
        {
            "id": "power_generator_large_250kva",
            "name": "Heavy Festival Twin-Pack Generator 250 kVA",
            "category": "Power",
            "subcategory": "Generators",
            "dimensions": {"x": 4.5, "y": 2.2, "z": 1.8},
            "weight_kg": 4200.0,
            "mesh_generator": "gen_generator",
            "tags": ["power", "generator", "twinpack", "250kva", "festival grid"],
            "snap_points": []
        },
        {
            "id": "power_ballast_water_tank_1000l",
            "name": "Ballast Water Tank (IBC 1000L)",
            "category": "Power",
            "subcategory": "Ballast & Ground",
            "dimensions": {"x": 1.0, "y": 1.15, "z": 1.2},
            "weight_kg": 1050.0,
            "mesh_generator": "gen_ballast_tank",
            "tags": ["power", "ballast", "ibc", "water tank", "counterweight"],
            "snap_points": [
                {"pos": [0.0, 0.575, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "ground_ballast"}
            ]
        },
        {
            "id": "power_ballast_concrete_block_1t",
            "name": "Solid Cast Concrete Ballast Cube 1 Ton",
            "category": "Power",
            "subcategory": "Ballast & Ground",
            "dimensions": {"x": 0.8, "y": 0.8, "z": 0.8},
            "weight_kg": 1000.0,
            "mesh_generator": "gen_ballast_concrete",
            "tags": ["power", "concrete", "ballast", "1000kg", "counterweight"],
            "snap_points": [
                {"pos": [0.0, 0.4, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "ground_ballast"}
            ]
        },
        {
            "id": "power_cable_crossover_driveover",
            "name": "Vehicle Drive-Over Cable Trench 1m",
            "category": "Power",
            "subcategory": "Cable Infrastructure",
            "dimensions": {"x": 1.0, "y": 0.08, "z": 0.6},
            "weight_kg": 24.0,
            "mesh_generator": "gen_cable_ramp",
            "tags": ["power", "cable", "trench", "drive over", "heavy crossover"],
            "snap_points": [
                {"pos": [-0.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "cable_trench_link"},
                {"pos": [0.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "cable_trench_link"}
            ]
        },
        {
            "id": "power_cable_coil_camlock",
            "name": "Camlock 4/0 Single-Pin Cable Bundle (25m)",
            "category": "Power",
            "subcategory": "Cable Infrastructure",
            "dimensions": {"x": 0.8, "y": 0.4, "z": 0.8},
            "weight_kg": 45.0,
            "mesh_generator": "gen_cable_coil",
            "tags": ["power", "camlock", "cables", "coil", "feeder"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 9. DJ & BACKLINE (12 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "dj_booth_curved_facade",
            "name": "Curved LED-Backlit DJ Booth Facade",
            "category": "DJ & Backline",
            "subcategory": "DJ Furniture",
            "dimensions": {"x": 2.2, "y": 1.1, "z": 0.9},
            "weight_kg": 42.0,
            "mesh_generator": "gen_dj_booth_curved",
            "tags": ["dj", "booth", "facade", "curved", "performance"],
            "variants": [
                {"id": "white", "name": "Gloss White", "material": "facade_white"},
                {"id": "black", "name": "Matte Black", "material": "stage_black_deck"}
            ],
            "snap_points": [
                {"pos": [0.0, 0.5, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "dj_surface"}
            ]
        },
        {
            "id": "dj_table_folding_pro",
            "name": "Folding Aluminum Pro DJ Table",
            "category": "DJ & Backline",
            "subcategory": "DJ Furniture",
            "dimensions": {"x": 1.5, "y": 0.95, "z": 0.6},
            "weight_kg": 24.0,
            "mesh_generator": "gen_dj_table_folding",
            "tags": ["dj", "table", "stand", "folding", "aluminum"],
            "snap_points": [
                {"pos": [0.0, 0.475, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "dj_surface"}
            ]
        },
        {
            "id": "dj_setup_2deck",
            "name": "2-Deck CDJ + 2-Channel Battle Mixer",
            "category": "DJ & Backline",
            "subcategory": "DJ Gear",
            "dimensions": {"x": 1.1, "y": 0.2, "z": 0.5},
            "weight_kg": 19.0,
            "mesh_generator": "gen_dj_setup",
            "tags": ["dj", "cdj", "mixer", "2-deck", "battle mixer"],
            "snap_points": [
                {"pos": [0.0, -0.1, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "dj_surface"}
            ]
        },
        {
            "id": "dj_setup_4deck",
            "name": "Pro 4-Deck Flagship DJ Flightcase",
            "category": "DJ & Backline",
            "subcategory": "DJ Gear",
            "dimensions": {"x": 1.5, "y": 0.22, "z": 0.52},
            "weight_kg": 28.0,
            "mesh_generator": "gen_dj_setup",
            "tags": ["dj", "cdj", "4-deck", "players", "club standard"],
            "snap_points": [
                {"pos": [0.0, -0.11, 0.0], "normal": [0.0, -1.0, 0.0], "tag": "dj_surface"}
            ]
        },
        {
            "id": "dj_mixer_club_4ch",
            "name": "Standalone 4-Channel Club Mixer",
            "category": "DJ & Backline",
            "subcategory": "DJ Gear",
            "dimensions": {"x": 0.43, "y": 0.12, "z": 0.46},
            "weight_kg": 10.5,
            "mesh_generator": "gen_dj_mixer",
            "tags": ["dj", "mixer", "4-channel", "club mixer", "dsp"],
            "snap_points": []
        },
        {
            "id": "backline_drum_kit_complete",
            "name": "5-Piece Touring Acoustic Drum Kit",
            "category": "DJ & Backline",
            "subcategory": "Instruments",
            "dimensions": {"x": 1.8, "y": 1.4, "z": 1.8},
            "weight_kg": 65.0,
            "mesh_generator": "gen_backline_drums",
            "tags": ["backline", "drums", "cymbals", "kick drum", "acoustic"],
            "variants": [
                {"id": "black", "name": "Midnight Black Sparkle", "material": "drum_shell_black"},
                {"id": "white", "name": "Pearl White", "material": "drum_shell_white"}
            ],
            "snap_points": []
        },
        {
            "id": "backline_guitar_halfstack",
            "name": "Tube Guitar Amp Head over 4x12 Cab",
            "category": "DJ & Backline",
            "subcategory": "Amplifiers",
            "dimensions": {"x": 0.76, "y": 1.1, "z": 0.38},
            "weight_kg": 48.0,
            "mesh_generator": "gen_backline_guitar_amp",
            "tags": ["backline", "guitar", "amp", "marshall-style", "halfstack", "4x12"],
            "snap_points": []
        },
        {
            "id": "backline_bass_8x10_stack",
            "name": "Bass Amp Head with 8x10 Cabinet",
            "category": "DJ & Backline",
            "subcategory": "Amplifiers",
            "dimensions": {"x": 0.66, "y": 1.45, "z": 0.42},
            "weight_kg": 72.0,
            "mesh_generator": "gen_backline_bass_amp",
            "tags": ["backline", "bass", "amp", "8x10", "refrigerator cab"],
            "snap_points": []
        },
        {
            "id": "backline_keyboard_double_stand",
            "name": "88-Key Stage Piano on 2-Tier Stand",
            "category": "DJ & Backline",
            "subcategory": "Instruments",
            "dimensions": {"x": 1.4, "y": 1.1, "z": 0.6},
            "weight_kg": 32.0,
            "mesh_generator": "gen_backline_keyboard",
            "tags": ["backline", "keyboard", "piano", "synth", "stand"],
            "snap_points": []
        },
        {
            "id": "backline_guitar_multi_stand",
            "name": "5-Guitar Folding Stage Rack Stand",
            "category": "DJ & Backline",
            "subcategory": "Accessories",
            "dimensions": {"x": 0.85, "y": 0.75, "z": 0.45},
            "weight_kg": 5.5,
            "mesh_generator": "gen_backline_guitar_rack",
            "tags": ["backline", "guitar stand", "rack", "stage left"],
            "snap_points": []
        },
        {
            "id": "backline_acoustic_grand_piano",
            "name": "7-Foot Concert Grand Piano",
            "category": "DJ & Backline",
            "subcategory": "Instruments",
            "dimensions": {"x": 1.5, "y": 1.05, "z": 2.15},
            "weight_kg": 380.0,
            "mesh_generator": "gen_backline_grand_piano",
            "tags": ["backline", "grand piano", "acoustic", "concert piano", "steinway-style"],
            "snap_points": []
        },
        {
            "id": "backline_percussion_conga_pair",
            "name": "Double Conga Drums on Chrome Stand",
            "category": "DJ & Backline",
            "subcategory": "Instruments",
            "dimensions": {"x": 0.85, "y": 1.2, "z": 0.55},
            "weight_kg": 26.0,
            "mesh_generator": "gen_backline_congas",
            "tags": ["backline", "percussion", "congas", "drums", "latin"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 10. ENVIRONMENT & SET DRESSING (13 items)
    # -------------------------------------------------------------
    drape_variants = [
        {"id": "black", "name": "Heavy Black Molton", "material": "drape_black"},
        {"id": "white", "name": "White Cyclorama", "material": "drape_white"},
        {"id": "burgundy", "name": "Deep Burgundy Velvet", "material": "drape_burgundy"}
    ]

    assets.extend([
        {
            "id": "env_backdrop_black_6x4m",
            "name": "Black Stage Molton Drape (6x4m)",
            "category": "Environment & Dressing",
            "subcategory": "Drapes",
            "dimensions": {"x": 6.0, "y": 4.0, "z": 0.05},
            "weight_kg": 14.0,
            "mesh_generator": "gen_stage_drape",
            "tags": ["environment", "backdrop", "drape", "molton", "blackout", "6x4"],
            "variants": drape_variants,
            "snap_points": [
                {"pos": [0.0, 2.0, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "pipe_and_drape"}
            ]
        },
        {
            "id": "env_backdrop_black_10x6m",
            "name": "Heavy Stage Cyc Backdrop (10x6m)",
            "category": "Environment & Dressing",
            "subcategory": "Drapes",
            "dimensions": {"x": 10.0, "y": 6.0, "z": 0.05},
            "weight_kg": 35.0,
            "mesh_generator": "gen_stage_drape",
            "tags": ["environment", "backdrop", "large cyc", "curtain", "10x6"],
            "variants": drape_variants,
            "snap_points": [
                {"pos": [0.0, 3.0, 0.0], "normal": [0.0, 1.0, 0.0], "tag": "pipe_and_drape"}
            ]
        },
        {
            "id": "env_backdrop_starcloth_fiber",
            "name": "LED Fiber-Optic Starcloth (8x4m)",
            "category": "Environment & Dressing",
            "subcategory": "Drapes",
            "dimensions": {"x": 8.0, "y": 4.0, "z": 0.08},
            "weight_kg": 26.0,
            "mesh_generator": "gen_stage_starcloth",
            "tags": ["environment", "starcloth", "sparkle", "fiber optic", "twinkle"],
            "snap_points": []
        },
        {
            "id": "env_scrim_pa_banner_8x3m",
            "name": "Acoustic Mesh PA Scrim Banner 8x3m",
            "category": "Environment & Dressing",
            "subcategory": "Drapes",
            "dimensions": {"x": 3.0, "y": 8.0, "z": 0.02},
            "weight_kg": 6.5,
            "mesh_generator": "gen_scrim_banner",
            "tags": ["environment", "banner", "scrim", "mesh", "pa cover", "branding"],
            "snap_points": []
        },
        {
            "id": "env_fence_heras_panel_35m",
            "name": "Heras Security Fence Panel 3.5x2.0m",
            "category": "Environment & Dressing",
            "subcategory": "Fencing",
            "dimensions": {"x": 3.5, "y": 2.0, "z": 0.45},
            "weight_kg": 18.5,
            "mesh_generator": "gen_heras_fence",
            "tags": ["environment", "fence", "heras", "perimeter", "security", "boundary"],
            "snap_points": [
                {"pos": [-1.75, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "fence_link"},
                {"pos": [1.75, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "fence_link"}
            ]
        },
        {
            "id": "env_barrier_bikerack_25m",
            "name": "Pedestrian Bike-Rack Barricade 2.5m",
            "category": "Environment & Dressing",
            "subcategory": "Fencing",
            "dimensions": {"x": 2.5, "y": 1.1, "z": 0.5},
            "weight_kg": 16.0,
            "mesh_generator": "gen_bikerack_barrier",
            "tags": ["environment", "barricade", "bike rack", "crowd control", "queue"],
            "snap_points": [
                {"pos": [-1.25, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "bikerack_hook"},
                {"pos": [1.25, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "bikerack_hook"}
            ]
        },
        {
            "id": "env_tree_ornamental_3m",
            "name": "Live Potted Stage Tree 3m",
            "category": "Environment & Dressing",
            "subcategory": "Greenery",
            "dimensions": {"x": 1.4, "y": 3.2, "z": 1.4},
            "weight_kg": 45.0,
            "mesh_generator": "gen_tree_prop",
            "tags": ["environment", "tree", "plant", "greenery", "organic prop", "foliage"],
            "snap_points": []
        },
        {
            "id": "env_hedge_planter_box",
            "name": "Boxwood Privacy Hedge Planter 2m",
            "category": "Environment & Dressing",
            "subcategory": "Greenery",
            "dimensions": {"x": 2.0, "y": 1.2, "z": 0.45},
            "weight_kg": 28.0,
            "mesh_generator": "gen_hedge_prop",
            "tags": ["environment", "hedge", "planter", "greenery", "vip divider"],
            "snap_points": []
        },
        {
            "id": "env_portable_toilet_cubicle",
            "name": "Event Portable Toilet Cubicle (Porta-potty)",
            "category": "Environment & Dressing",
            "subcategory": "Site Facilities",
            "dimensions": {"x": 1.15, "y": 2.3, "z": 1.2},
            "weight_kg": 85.0,
            "mesh_generator": "gen_portable_toilet",
            "tags": ["environment", "toilet", "porta potty", "restroom", "festival site"],
            "snap_points": [
                {"pos": [-0.575, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "toilet_row"},
                {"pos": [0.575, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "toilet_row"}
            ]
        },
        {
            "id": "env_food_trailer_concession",
            "name": "Festival Food & Beverage Trailer",
            "category": "Environment & Dressing",
            "subcategory": "Site Facilities",
            "dimensions": {"x": 4.5, "y": 2.6, "z": 2.2},
            "weight_kg": 1400.0,
            "mesh_generator": "gen_food_trailer",
            "tags": ["environment", "trailer", "food stall", "bar", "concession"],
            "snap_points": []
        },
        {
            "id": "env_vehicle_golf_cart",
            "name": "Production 4-Seater Golf Buggy",
            "category": "Environment & Dressing",
            "subcategory": "Vehicles",
            "dimensions": {"x": 2.6, "y": 1.85, "z": 1.2},
            "weight_kg": 420.0,
            "mesh_generator": "gen_golf_cart",
            "tags": ["environment", "vehicle", "buggy", "golf cart", "production runner"],
            "snap_points": []
        },
        {
            "id": "env_vehicle_truck_trailer_40ft",
            "name": "40ft Enclosed Logistics Equipment Trailer",
            "category": "Environment & Dressing",
            "subcategory": "Vehicles",
            "dimensions": {"x": 13.6, "y": 4.0, "z": 2.55},
            "weight_kg": 7200.0,
            "mesh_generator": "gen_truck_trailer",
            "tags": ["environment", "semi truck", "trailer", "loading dock", "freight"],
            "snap_points": []
        },
        {
            "id": "env_signage_emergency_exit",
            "name": "Illuminated Emergency Exit Sign",
            "category": "Environment & Dressing",
            "subcategory": "Signage",
            "dimensions": {"x": 0.6, "y": 0.3, "z": 0.05},
            "weight_kg": 2.0,
            "mesh_generator": "gen_exit_sign",
            "tags": ["environment", "sign", "exit", "emergency", "safety green"],
            "snap_points": []
        }
    ])

    # -------------------------------------------------------------
    # 11. CROWD (6 items)
    # -------------------------------------------------------------
    assets.extend([
        {
            "id": "crowd_single_standing",
            "name": "Single Spectator Figure (Standing)",
            "category": "Crowd",
            "subcategory": "Figures",
            "dimensions": {"x": 0.45, "y": 1.75, "z": 0.3},
            "weight_kg": 70.0,
            "mesh_generator": "gen_crowd_figure",
            "tags": ["crowd", "human", "scale reference", "audience", "person"],
            "snap_points": []
        },
        {
            "id": "crowd_single_seated",
            "name": "Single Spectator Figure (Seated)",
            "category": "Crowd",
            "subcategory": "Figures",
            "dimensions": {"x": 0.45, "y": 1.25, "z": 0.55},
            "weight_kg": 70.0,
            "mesh_generator": "gen_crowd_figure_seated",
            "tags": ["crowd", "seated", "chair", "audience", "theatre"],
            "snap_points": []
        },
        {
            "id": "crowd_block_low_50pax",
            "name": "Crowd Block 10x10m (Low: 50 pax MultiMesh)",
            "category": "Crowd",
            "subcategory": "MultiMesh Blocks",
            "dimensions": {"x": 10.0, "y": 1.8, "z": 10.0},
            "weight_kg": 3500.0,
            "mesh_generator": "gen_crowd_multimesh_block_50",
            "tags": ["crowd", "multimesh", "low density", "spacious", "50pax"],
            "snap_points": []
        },
        {
            "id": "crowd_block_medium_100pax",
            "name": "Crowd Block 10x10m (Standard: 100 pax MultiMesh)",
            "category": "Crowd",
            "subcategory": "MultiMesh Blocks",
            "dimensions": {"x": 10.0, "y": 1.8, "z": 10.0},
            "weight_kg": 7000.0,
            "mesh_generator": "gen_crowd_multimesh_block",
            "tags": ["crowd", "multimesh", "festival", "standard", "100pax"],
            "snap_points": []
        },
        {
            "id": "crowd_block_high_200pax",
            "name": "Crowd Block 10x10m (High Pit: 200 pax MultiMesh)",
            "category": "Crowd",
            "subcategory": "MultiMesh Blocks",
            "dimensions": {"x": 10.0, "y": 1.8, "z": 10.0},
            "weight_kg": 14000.0,
            "mesh_generator": "gen_crowd_multimesh_block_200",
            "tags": ["crowd", "multimesh", "pit", "mosh", "dense", "200pax"],
            "snap_points": []
        },
        {
            "id": "crowd_grandstand_row_10seats",
            "name": "Grandstand Bleacher Row (10 Seats)",
            "category": "Crowd",
            "subcategory": "Seating",
            "dimensions": {"x": 5.0, "y": 0.85, "z": 0.75},
            "weight_kg": 120.0,
            "mesh_generator": "gen_grandstand_row",
            "tags": ["crowd", "seats", "bleachers", "grandstand", "stadium seats"],
            "snap_points": [
                {"pos": [-2.5, 0.0, 0.0], "normal": [-1.0, 0.0, 0.0], "tag": "bleacher_side"},
                {"pos": [2.5, 0.0, 0.0], "normal": [1.0, 0.0, 0.0], "tag": "bleacher_side"}
            ]
        }
    ])

    return {
        "$schema": "./catalog.schema.json",
        "version": "2.0.0",
        "name": "Stage-Builder Comprehensive Production Equipment Catalog",
        "assets": assets
    }

if __name__ == "__main__":
    catalog_data = build_catalog()
    out_path = Path(__file__).resolve().parent.parent.parent / "data" / "catalog.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(catalog_data, f, indent=2)
    print(f"Generated Phase 2 catalog with {len(catalog_data['assets'])} assets at: {out_path}")

