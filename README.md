# Stage-Builder

[![Godot Engine](https://img.shields.io/badge/Godot-4.x%20(Forward%2B%20%2F%20Compatibility)-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20macOS-blue)](#system-requirements)
[![Scale](https://img.shields.io/badge/Scale-1%20unit%20%3D%201%20meter-green)](#real-world-scale)
[![Catalog](https://img.shields.io/badge/Equipment%20Catalog-146%20Assets-orange)](#equipment-catalog-146-assets)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

**Stage-Builder** is a high-performance native desktop 3D simulator for designing event stages (concerts, music festivals, club nights, and corporate productions). Users place real-world production equipment into a 3D scene at true scale, assemble modular trussing and staging, configure equipment color/material variants, import custom 3D models, calculate equipment weight loads, and design stages.

> **Hard Constraints**  
> * **Native Desktop Only**: No webview, Electron, or browser dependencies.  
> * **Target Operating Systems**: Windows 10/11 (x86_64) and macOS (Apple Silicon + Intel Universal).  
> * **Real-World Scale**: Exactly **1 Godot unit = 1 meter**. All dimensions and weights are true to physical stage equipment.  
> * **Data-Driven Catalog**: Procedural or original primitive-based assets with generic industry names (zero copyrighted models or trademarked brands).  
> * **User Asset Import**: Clean GLTF/GLB import pipeline validating geometry scale and polygon counts, persisting safely in user application storage.

---

## Table of Contents
1. [Key Features](#key-features)
2. [Quickstart & Running](#quickstart--running)
   - [Windows 10 / 11](#windows-10--11)
   - [macOS (Apple Silicon & Intel)](#macos-apple-silicon--intel)
3. [Building & Exporting](#building--exporting)
4. [Controls & Shortcuts](#controls--shortcuts)
5. [Equipment Catalog (146 Assets Across 11 Categories)](#equipment-catalog-146-assets-across-11-categories)
6. [Asset Import Pipeline (GLTF / GLB)](#asset-import-pipeline-gltf--glb)
7. [Testing & Quality Verification](#testing--quality-verification)
8. [What's Done & What's Next](#whats-done--whats-next)

---

## Key Features

* **Professional Dark UI Layout & Upgraded Browser**:
  - Menu Bar (File, Edit, View, Ground, Help) with one-click `Import 3D Asset...`.
  - **Automatic HiDPI UI Scaling**: Dynamic scaling across 1080p to 4K and macOS Retina (1.0x to 3.0x in 0.25 steps) while keeping the 3D viewport rendered at native physical resolution (no blurry 3D).
  - Left Asset Browser with real-time search, category & subcategory filters, **Grid View** vs **List View** toggle.
  - **Favorites (★)** and **Recently Used (🕒)** equipment tabs.
  - Auto-generated cached 128x128 PNG thumbnails rendered into `user://thumbnails/`.
  - Interactive 3D Viewport with dynamic 1m / 5m grid, colored axes, and soft dusk sky.
  - Right Properties Panel: transform, dimensions, weight, custom notes, and dynamic **Material Variant Picker**.
  - Bottom Status Bar with live FPS, object count, total stage load in kg, and snapping toggles.
* **Material & Color Variants**:
  - Full variant system per asset (e.g. natural aluminum, matte black, gloss white for truss; black, navy blue, crimson red for flight cases).
  - Live preview and material swapping with undo/redo support via `VariantChangeCommand`.
* **User 3D Asset Import Pipeline (GLTF / GLB)**:
  - Wizard dialog under `File > Import 3D Asset (GLTF/GLB)...`.
  - Pre-flight validation: warns if polycount exceeds 150k triangles or if bounding box exceeds 500m / <0.005m.
  - Saves models to `user://imported_assets/` (outside the repo) and registers them automatically in `user://imported_catalog.json`.
* **Dual Snapping System**:
  - **Snap-Point-to-Snap-Point**: Automatic magnetic alignment for modular truss connections (`truss_box`, `truss_tri`, `tower_section`) and stage decks (`deck_edge_1m`, `deck_edge_2m`).
  - **Grid Snapping**: Configurable grid step (0.25m, 0.50m, 1.00m) and riser height snapping (0.1m, 0.4m).
* **3D Transform Gizmo & Navigation**:
  - Interactive 3-axis translation arrows (Red = X, Green = Y, Blue = Z) and ground plane handle.
  - Y-axis rotation ring with optional 15° angular snapping.
  - Full CAD camera navigation: Orbit, Pan, Zoom, WASD Fly Mode, and Quick Views (Top, Front, Side, Perspective).
  - Native trackpad support on macOS (two-finger pan, pinch-to-zoom).
* **Command-Pattern Undo / Redo**:
  - Non-destructive history for placement, deletion, transformation, property editing, variant switching, and grouping (`Ctrl/Cmd+Z` / `Ctrl/Cmd+Y`).
* **Projects & Backward Compatibility**:
  - Single-file `.stagebuilder` JSON project format with automatic Phase 1 backward compatibility.
  - Background autosave every 120 seconds.
  - High-resolution viewport screenshot export (`PNG`).
* **Performance & Frame Rate Settings**:
  - Configure via `View > Performance` submenu or the dedicated `Performance & Frame Rate Settings` dialog.
  - Three operational modes:
    - **VSync (Default)**: `DisplayServer.window_set_vsync_mode(VSYNC_ENABLED)`, `Engine.max_fps = 0`. Synchronizes frames to monitor refresh rate with zero screen tearing.
    - **Custom FPS Limit**: `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`, `Engine.max_fps = N` (clamped 15–1000) with quick presets: 30, 60, 90, 120, 144, 240.
    - **Unlimited**: `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`, `Engine.max_fps = 0`. Renders as fast as hardware permits.
  - **Background Power Saving**: Automatically caps engine to 30 FPS when window is unfocused or minimized (default enabled).
  - **Status Bar Display**: Real-time counter showing mode (e.g. `FPS: 60 (VSync)`, `FPS: 144 (Limit 144)`, `FPS: 612 (Unlimited)`), readable at every UI scale tier with click-to-open shortcut.
  - **Platform-Specific Behavior**:
    - *Windows*: VSync locks to active monitor scanlines; Unlimited unlocks raw GPU presentation.
    - *macOS*: The system compositor (Metal) enforces display synchronization system-wide; "Unlimited" is constrained to the active display's refresh rate (e.g. 60Hz or 120Hz ProMotion).
* **60 FPS Performance (5,000+ Objects)**:
  - MultiMesh instancing for crowd audience blocks.
  - Shared PBR materials and lightweight procedural geometry.

---

## Quickstart & Running

### Windows 10 / 11

1. **Install Godot 4.x**:
   ```powershell
   winget install GodotEngine.GodotEngine
   ```
2. **Clone & Open Project**:
   ```powershell
   cd Stage-Builder
   godot --editor project.godot
   ```
   Or run the application directly:
   ```powershell
   godot --scene res://scenes/main.tscn
   ```

3. **Activate Python Virtual Environment (Tooling & Validation)**:
   ```powershell
   .\.venv\Scripts\Activate.ps1
   python scripts\tools\catalog_validator.py
   ```

---

### macOS (Apple Silicon & Intel)

1. **Install Godot 4.x**:
   ```bash
   brew install --cask godot
   ```
2. **Open Project**:
   ```bash
   cd Stage-Builder
   godot -e project.godot
   ```
   Or run the application:
   ```bash
   godot res://scenes/main.tscn
   ```

3. **Python Tooling**:
   ```bash
   source .venv/bin/activate
   python scripts/tools/catalog_validator.py
   ```

---

## Building & Exporting

Export presets for Windows (x86_64) and macOS (Universal) are configured in `export_presets.cfg`.

### Windows Export
```powershell
mkdir -p build/windows
godot --headless --export-release "Windows Desktop" build/windows/Stage-Builder.exe
```

### macOS Export
```bash
mkdir -p build/macos
godot --headless --export-release "macOS" build/macos/Stage-Builder.dmg
```

---

## Controls & Shortcuts

Stage-Builder detects the host operating system automatically and maps shortcuts to **Command (`Cmd`)** on macOS and **Control (`Ctrl`)** on Windows:

| Action | Windows Shortcut | macOS Shortcut | Mouse / Trackpad |
| :--- | :--- | :--- | :--- |
| **Orbit Camera** | `Alt + LMB` | `Option + LMB` | Middle Mouse Button (drag) |
| **Pan Camera** | `Shift + MMB` | `Shift + MMB` | Two-Finger Trackpad Drag |
| **Zoom Viewport** | `Wheel Up / Down` | `Wheel Up / Down` | Two-Finger Trackpad Pinch |
| **WASD Fly Mode** | Hold `RMB` + `WASD` | Hold `RMB` + `WASD` | `Q` (Down) / `E` (Up) / `Shift` (Boost) |
| **Top View** | `Numpad 7` | `Numpad 7` | Menu: View -> Top View |
| **Front View** | `Numpad 1` | `Numpad 1` | Menu: View -> Front View |
| **Side View** | `Numpad 3` | `Numpad 3` | Menu: View -> Side View |
| **Perspective View**| `Numpad 0` | `Numpad 0` | Menu: View -> Perspective |
| **Frame Selection** | `F` | `F` | Menu: View -> Frame Selection |
| **Select Object / Group** | `LMB` | `LMB` | Click object (clicks member selects whole group) |
| **Multi-Select** | `Ctrl + LMB` / `Shift + LMB` | `Cmd + LMB` / `Shift + LMB` | Click multiple objects |
| **Box Select** | Drag on canvas | Drag on canvas | Drag rectangle in empty space |
| **Transform Gizmo** | Drag Gizmo Handles | Drag Gizmo Handles | Red (X), Green (Y), Blue (Z), Cyan (Rot) |
| **Rotate Placement Ghost** | `R` (+90°) / `Shift + R` (-90°) | `R` / `Shift + R` | Rotates ghost preview before placing |
| **Continuous Placement** | Hold `Shift` + `LMB` | Hold `Shift` + `LMB` | Keep placing copies without exiting placement |
| **Cancel Placement** | `Esc` / `RMB` | `Esc` / `RMB` | Cancel active placement preview |
| **Temporary Snap Override** | Hold `Alt` / `Option` | Hold `Alt` / `Option` | Disables all snapping while dragging/placing |
| **Duplicate** | `Ctrl + D` | `Cmd + D` | Menu: Edit -> Duplicate |
| **Delete** | `Delete` / `Backspace` | `Delete` / `Backspace` | Menu: Edit -> Delete |
| **Group Selection** | `Ctrl + G` | `Cmd + G` | Menu: Edit -> Group (hierarchical StageGroup) |
| **Ungroup Selection** | `Ctrl + Shift + G` | `Cmd + Shift + G` | Menu: Edit -> Ungroup |
| **Undo / Redo** | `Ctrl + Z` / `Ctrl + Y` | `Cmd + Z` / `Cmd + Shift + Z` | Menu: Edit -> Undo / Redo |
| **Import 3D Asset** | `Ctrl + I` | `Cmd + I` | Menu: File -> Import 3D Asset... |
| **Save Project** | `Ctrl + S` | `Cmd + S` | Menu: File -> Save |
| **Open Project** | `Ctrl + O` | `Cmd + O` | Menu: File -> Open |
| **Export Screenshot** | `Ctrl + E` | `Cmd + E` | Saves PNG to `user://screenshots/` |
| **Toggle 3D Grid** | `G` | `G` | Menu: View -> Show 3D Grid |
| **Toggle Point Snapping** | `S` | `S` | Menu: View -> Snap to Grid / Status Bar |
| **Toggle Catalog** | `Ctrl + [` | `Cmd + [` | Header Button: ◀ / ▶ |
| **Toggle Properties** | `Ctrl + ]` | `Cmd + ]` | Header Button: ◀ / ▶ |

---

## Equipment Catalog (146 Assets Across 11 Categories)

All assets are defined in `data/catalog.json` with real physical dimensions, weights, variants, and snap points:

| Category | Count | Subcategories | Key Equipment Examples |
| :--- | :--- | :--- | :--- |
| **Truss** | 24 | Box Truss, Triangle Truss, Junctions, Towers, Accessories | Straight (0.29m to 4m), 2-Way Corners (90°, 120°, 135°), 3-Way T, 4-Way Cross, 6-Way Box, Sleeve Blocks, Heavy Base Plates |
| **Roof & Structure** | 13 | Towers, Stage Roofs, Wings, Tents, Scaffolding | Pitch & Arc Roofs (Small, Medium, Large), Ground Support Towers, Delay Towers, PA Wings, FOH Tents, Scaffolding Decks & Stairs |
| **Rigging** | 9 | Hoists & Motors, Hardware, Bridles & Slings | Electric Chain Hoists (0.5t, 1t, 2t), 8-Way Motor Controllers, Bow Shackles (3.25t, 4.75t), Spansets, Beam Clamps, Safety Bonds |
| **Staging** | 17 | Decks, Risers, Skirting & Ramps, Stairs, Barriers | Modular Decks (2x1m, 1x1m, 2x2m, 1x0.5m, triangular), Drum/DJ Risers, 4m Access Ramp, Modular Stairs (2/4/6 step), Crowd Barriers (Mojo) |
| **Audio** | 18 | Line Arrays, Subwoofers, Fills & Monitors, Consoles & Racks, Accessories | Compact/Touring/Stadium Line Arrays, Single/Dual 18" & Cardioid Subs, 12"/15" Floor Wedges, Sidefills, FOH Consoles, 12U Amp Racks, Cable Ramps |
| **Lighting** | 14 | Moving Heads, Static Fixtures, Effects, Control, Rigging | Beam, Spot, and Wash Moving Heads, Touring LED PARs, Pixel Bars, Atomic LED Strobes, 2/4-Lite Blinders, Followspots, Touring Consoles, Hazers |
| **Video** | 10 | LED Wall Panels, Projection, Video Infrastructure, Cameras | 0.5x0.5m & 0.5x1m LED Panels, Ground Support Frames, 16:9 Fast-Fold Screens, 20K Laser Projectors, Video Switcher Racks, Pedestal Cameras, Jib Cranes |
| **Power** | 10 | Distribution, Generators, Ballast, Cable Management | 32A, 63A, 125A Distro Racks, 30kVA to 250kVA Generators, 1000L IBC Ballast Tanks, 1-Ton Concrete Blocks, Drive-Over Cable Crossovers |
| **DJ & Backline** | 12 | DJ Furniture & Setups, Instruments & Amps, Stands | Curved DJ Facades, Folding Tables, 2-Deck & 4-Deck Flight Cases, 4-Ch Club Mixers, Guitar Amps, Bass Stacks, Drum Kits, Synthesizers |
| **Environment & Dressing** | 13 | Drapes & Banners, Perimeter & Fencing, Site Amenities | Stage Backdrops & Drapes, Printed Sponsor Banners, Temporary Fencing, Portable Sanitation Cabins, Catering Food Trucks, Production Trailers |
| **Crowd** | 6 | Individuals, Crowd Blocks, Seating | Single Standing & Seated Spectators, MultiMesh Crowd Blocks (50, 100, 200 pax for instant 60 FPS rendering), Grandstand Seating Rows |

---

## Asset Import Pipeline (GLTF / GLB)

To import external 3D equipment models:
1. Choose **File > Import 3D Asset (GLTF/GLB)...** (or press `Ctrl+I` / `Cmd+I`).
2. Select your `.glb` or `.gltf` model file.
3. The wizard validates model geometry, displays triangle counts, and flags abnormal dimensions (e.g. models not exported in 1 unit = 1 meter).
4. Assign category, subcategory, physical dimensions, weight, and multiple snap points.
5. Click **Import & Add to Library**. The asset is copied to `user://imported_assets/` and registered into your local catalog automatically.

For a complete walkthrough, see [docs/asset_pipeline.md](file:///c:/Users/gupta/Documents/Development/Stage-Builder/docs/asset_pipeline.md).

---

## Testing & Quality Verification

### Run Input-Simulation Test Suite
Simulates real hardware events (`InputEventKey`, `InputEventMouseButton`, `InputEventMouseMotion`) through the real engine input pipeline to prove interaction behaviors:
```powershell
godot --headless --scene res://scenes/test/input_test_runner.tscn
```

### Run Automated Integration Test Suite
Executes 10 integration test suites verifying 146+ catalog assets, procedural mesh builders, variant switching, asset import round-trip, grid/point snapping, undo/redo commands, Phase 1 backward compatibility, raycasting precision, stacking, and HiDPI UI scaling:
```powershell
godot --headless --scene res://scenes/test/test_runner.tscn
```

### Run 5,000-Object Stress Test (60 FPS Verification)
Renders a concert arena with 5,000 spectator figures using `MultiMeshInstance3D` to benchmark viewport framerate:
```powershell
godot --scene res://scenes/test/test_performance.tscn
```

### Run Catalog Validation Tool
Verifies schema compliance, unique IDs, positive bounding boxes, snap point formats, and valid material variant references:
```powershell
python scripts/tools/catalog_validator.py
```

---

## What's Done & What's Next

### What's Done (Phase 1 & Phase 2 Complete)
- [x] Full Godot 4.x desktop project structure with Forward+ and Compatibility fallbacks.
- [x] Python virtual environment (`.venv`) and `catalog_validator.py` with 0 errors.
- [x] 146 production equipment assets across 11 categories and 51 subcategories in `data/catalog.json`.
- [x] Procedural primitive-based 3D mesh generator with shared PBR materials for all 146 assets.
- [x] Material & color variant system (aluminum, powdercoats, flight case colors, drape fabrics) with runtime picker and undo/redo support.
- [x] GLTF / GLB asset import pipeline with polycount and scale validation, saving outside repo to `user://imported_assets/`.
- [x] Upgraded Asset Browser: Subcategories, Favorites (★), Recently Used (🕒), Grid vs. List view toggle, and cached 128x128 thumbnails.
- [x] Backward compatibility engine: seamlessly loads Phase 1 project files via legacy ID aliases.
- [x] Automated test suite with 6 comprehensive test suites passing with 100% success rate.
- [x] 60 FPS hold verified with 5,000 instanced objects.
- [x] Comprehensive documentation in `docs/architecture.md`, `docs/asset_pipeline.md`, and `README.md`.

### What's Next (Phase 3 Roadmap)
- [ ] DMX Lighting Controller integration (simulated beam cones, spot gobos, wash angles, color palettes).
- [ ] Rigging Load & Truss Stress Calculation Engine (real-time point-load calculations, bridle tension vectors, overload warning indicators).
- [ ] 2D Technical Stage Plot & Equipment Manifest PDF exporter.
- [ ] Sound Coverage Heatmaps (SPL dispersion and frequency response visualization for line arrays and cardioid sub stacks).
- [ ] Multi-camera director preview system (simulating broadcast camera angles and live switcher views).
