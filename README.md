# Stage-Builder

[![Godot Engine](https://img.shields.io/badge/Godot-4.x%20(Forward%2B%20%2F%20Compatibility)-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20macOS-blue)](#system-requirements)
[![Scale](https://img.shields.io/badge/Scale-1%20unit%20%3D%201%20meter-green)](#real-world-scale)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

**Stage-Builder** is a high-performance native desktop 3D simulator for designing event stages (concerts, music festivals, club nights, and corporate productions). Users place real-world production equipment into a 3D scene at true scale, assemble modular trussing and staging, calculate equipment weight loads, and design stages.

> **Hard Constraints**  
> * **Native Desktop Only**: No webview, Electron, or browser dependencies.  
> * **Target Operating Systems**: Windows 10/11 (x86_64) and macOS (Apple Silicon + Intel Universal).  
> * **Real-World Scale**: Exactly **1 Godot unit = 1 meter**. All dimensions and weights are true to physical stage equipment.  
> * **Data-Driven Catalog**: Procedural or original primitive-based assets with generic industry names (zero copyrighted models or trademarked brands).  

---

## Table of Contents
1. [Key Features](#key-features)
2. [Quickstart & Running](#quickstart--running)
   - [Windows 10 / 11](#windows-10--11)
   - [macOS (Apple Silicon & Intel)](#macos-apple-silicon--intel)
3. [Building & Exporting](#building--exporting)
4. [Controls & Shortcuts](#controls--shortcuts)
5. [Equipment Catalog (27 Assets)](#equipment-catalog-27-assets)
6. [Testing & Quality Verification](#testing--quality-verification)
7. [What's Done & What's Next](#whats-done--whats-next)

---

## Key Features

* **Professional Dark UI Layout**:
  - Menu Bar (File, Edit, View, Ground, Help).
  - Left Asset Browser with real-time search, category filters, and instant placement.
  - Interactive 3D Viewport with dynamic 1m / 5m grid, colored axes, and soft dusk sky.
  - Right Properties Panel: single-object inspector, multi-selection batch actions, and stage weight overview.
  - Bottom Status Bar with live FPS, object count, total stage load in kg, and snapping toggles.
* **Dual Snapping System**:
  - **Snap-Point-to-Snap-Point**: Automatic magnetic alignment for modular truss connections (`truss_30`, `tower_40`) and stage decks (`deck_edge_1m`, `deck_edge_2m`).
  - **Grid Snapping**: Configurable grid step (0.25m, 0.50m, 1.00m) and riser height snapping (0.1m, 0.4m).
* **3D Transform Gizmo & Navigation**:
  - Interactive 3-axis translation arrows (Red = X, Green = Y, Blue = Z) and ground plane handle.
  - Y-axis rotation ring with optional 15° angular snapping.
  - Full CAD camera navigation: Orbit, Pan, Zoom, WASD Fly Mode, and Quick Views (Top, Front, Side, Perspective).
  - Native trackpad support on macOS (two-finger pan, pinch-to-zoom).
* **Command-Pattern Undo / Redo**:
  - Non-destructive history for placement, deletion, transformation, property editing, and grouping (`Ctrl/Cmd+Z` / `Ctrl/Cmd+Y`).
* **Projects & Export**:
  - Single-file `.stagebuilder` JSON project format.
  - Background autosave every 120 seconds.
  - High-resolution viewport screenshot export (`PNG`).
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

3. **Activate Python Virtual Environment (Optional Tooling)**:
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
| **Select Object** | `LMB` | `LMB` | Click on object collision |
| **Multi-Select** | `Ctrl + LMB` / `Shift + LMB` | `Cmd + LMB` / `Shift + LMB` | Click multiple objects |
| **Box Select** | Drag on canvas | Drag on canvas | Drag rectangle in empty space |
| **Transform Gizmo** | Drag Gizmo Handles | Drag Gizmo Handles | Red (X), Green (Y), Blue (Z), Cyan (Rot) |
| **Duplicate** | `Ctrl + D` | `Cmd + D` | Menu: Edit -> Duplicate |
| **Delete** | `Delete` / `Backspace` | `Delete` / `Backspace` | Menu: Edit -> Delete |
| **Group / Ungroup** | `Ctrl + G` / `Ctrl + Shift + G` | `Cmd + G` / `Cmd + Shift + G` | Menu: Edit -> Group / Ungroup |
| **Undo / Redo** | `Ctrl + Z` / `Ctrl + Y` | `Cmd + Z` / `Cmd + Shift + Z` | Menu: Edit -> Undo / Redo |
| **Save Project** | `Ctrl + S` | `Cmd + S` | Menu: File -> Save |
| **Open Project** | `Ctrl + O` | `Cmd + O` | Menu: File -> Open |
| **Export Screenshot** | `Ctrl + E` | `Cmd + E` | Saves PNG to `user://screenshots/` |
| **Toggle Grid** | `G` | `G` | Menu: View -> Show 3D Grid |
| **Toggle Snap** | `S` | `S` | Menu: View -> Snap to Grid |

---

## Equipment Catalog (27 Assets)

All assets are defined in `data/catalog.json` with physical dimensions and weights:

| Category | Asset Name | Dimensions (X x Y x Z) | Weight (kg) | Snap Points |
| :--- | :--- | :--- | :--- | :--- |
| **Truss** | Box Truss 0.5m | 0.3 x 0.3 x 0.5 m | 6.0 kg | Front / Back (`truss_30`) |
| **Truss** | Box Truss 1m | 0.3 x 0.3 x 1.0 m | 9.0 kg | Front / Back (`truss_30`) |
| **Truss** | Box Truss 2m | 0.3 x 0.3 x 2.0 m | 15.0 kg | Front / Back (`truss_30`) |
| **Truss** | Box Truss 3m | 0.3 x 0.3 x 3.0 m | 21.0 kg | Front / Back (`truss_30`) |
| **Truss** | Truss 6-Way Corner | 0.3 x 0.3 x 0.3 m | 8.0 kg | 6 Faces (`truss_30`) |
| **Truss** | Truss Tower Section | 0.4 x 2.0 x 0.4 m | 28.0 kg | Top / Bottom (`tower_40`) |
| **Truss** | Truss Base Plate 1m | 1.0 x 0.02 x 1.0 m | 45.0 kg | Top (`truss_30`, `tower_40`) |
| **Staging** | Stage Deck 2x1m | 2.0 x 0.4 x 1.0 m | 32.0 kg | 4 Edges (`deck_edge_1m`, `2m`) |
| **Staging** | Stage Deck 1x1m | 1.0 x 0.4 x 1.0 m | 18.0 kg | 4 Edges (`deck_edge_1m`) |
| **Staging** | Modular Stage Stairs | 1.0 x 0.8 x 1.2 m | 25.0 kg | Top Edge (`deck_edge_1m`) |
| **Staging** | Safety Handrail 2m | 2.0 x 1.1 x 0.05 m | 12.0 kg | Bottom Mount (`deck_edge_2m`) |
| **Staging** | Crowd Barrier (Mojo) | 1.0 x 1.2 x 0.8 m | 35.0 kg | Sides (`barrier_side`) |
| **Audio** | Line Array Module | 1.0 x 0.35 x 0.5 m | 42.0 kg | Top / Bottom Pin Links |
| **Audio** | Dual 18" Subwoofer | 1.2 x 0.6 x 0.8 m | 85.0 kg | Stack Top/Bottom & Sides |
| **Audio** | Stage Monitor Wedge | 0.6 x 0.35 x 0.45 m | 22.0 kg | Floor Placement |
| **Audio** | FOH Audio Console | 1.1 x 0.95 x 0.8 m | 48.0 kg | Floor Placement |
| **Audio** | Amp Rack Flight Case | 0.6 x 0.9 x 0.7 m | 75.0 kg | Top Stack |
| **Lighting** | Moving Head Spot/Wash | 0.45 x 0.7 x 0.4 m | 24.0 kg | Truss Clamp / Floor |
| **Lighting** | Touring PAR Can | 0.28 x 0.35 x 0.28 m| 4.5 kg | Truss Clamp |
| **Lighting** | LED Batten Bar 1m | 1.0 x 0.12 x 0.15 m | 6.0 kg | End Links |
| **Video** | LED Wall Panel (0.5x0.5m) | 0.5 x 0.5 x 0.08 m | 8.5 kg | 4 Edges (`led_wall_50`) |
| **Power** | Power Distro Rack | 0.6 x 0.85 x 0.6 m | 55.0 kg | Floor Placement |
| **Power** | Ballast Water Tank (IBC) | 1.0 x 1.15 x 1.2 m | 1050.0 kg | Top Rigging Mount |
| **DJ** | DJ Table with Booth | 1.8 x 1.0 x 0.75 m | 30.0 kg | Tabletop Surface |
| **DJ** | 4-Deck DJ Flight Case | 1.5 x 0.2 x 0.5 m | 26.0 kg | DJ Surface Mount |
| **Crowd** | Single Audience Figure | 0.45 x 1.75 x 0.3 m | 70.0 kg | Scale Reference |
| **Crowd** | Crowd Block (100x MultiMesh) | 10.0 x 1.8 x 10.0 m | 7000.0 kg | Single Draw Call |

---

## Testing & Quality Verification

### Run Automated Test Suite
Executes unit and integration tests across catalog instantiation, procedural builders, snapping, undo/redo, and file serialization:
```powershell
godot --headless --scene res://scenes/test/test_runner.tscn
```

### Run 5,000-Object Stress Test (60 FPS Verification)
Renders a concert arena with 5,000 spectator figures using `MultiMeshInstance3D` to benchmark viewport framerate:
```powershell
godot --scene res://scenes/test/test_performance.tscn
```

---

## What's Done & What's Next

### What's Done (Phase 1 Complete)
- [x] Full Godot 4.x desktop project structure with Forward+ and Compatibility fallbacks.
- [x] Python virtual environment (`.venv`) and `catalog_validator.py`.
- [x] Windows (`x86_64`) and macOS (`universal`) export configurations.
- [x] 27 production equipment assets across all 8 requested categories in `data/catalog.json`.
- [x] Procedural primitive-based 3D mesh generator with shared PBR materials (zero copyrighted models).
- [x] Professional dark UI layout (Menu Bar, Asset Browser, Properties Inspector, Status Bar).
- [x] 3D Viewport with 1m minor / 5m major dynamic grid, colored axes, and soft dusk sky.
- [x] Ground selector (Concrete Arena Slab, Festival Meadow Grass, Parking Lot Asphalt).
- [x] Camera system with Orbit, Pan, Zoom, WASD Fly Mode, Mac trackpad gestures, and Quick Views.
- [x] Interactive 3D Transform Gizmo (3-axis translation + Y rotation).
- [x] Grid snapping (0.25m, 0.5m, 1m) and Snap-Point-to-Snap-Point alignment (truss, decks, barriers).
- [x] Command-Pattern Undo / Redo (`Ctrl/Cmd+Z` / `Ctrl/Cmd+Y`).
- [x] Single-file `.stagebuilder` JSON project format, autosave, and recent files list.
- [x] High-resolution PNG viewport screenshot exporter.
- [x] Automated test runner (`test_runner.tscn`) and 5,000-object stress test (`test_performance.tscn`).
- [x] Architecture documentation in `docs/architecture.md`.

### What's Next (Phase 2 Roadmap)
- [ ] DMX Lighting Controller integration (simulated beam cones, gobo projections, color palettes).
- [ ] Truss Rigging Load & Stress Analysis (real-time point-load calculations and warning indicators).
- [ ] GLTF / FBX equipment model importer for custom user meshes.
- [ ] 2D Technical Stage Plot & Equipment Manifest PDF exporter.
- [ ] Sound Coverage Heatmaps (SPL dispersion visualization for line arrays and subwoofers).
