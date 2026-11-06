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

> [!WARNING]
> **DISCLAIMER: PLANNING AIDS ONLY — NOT STRUCTURAL CERTIFICATION**  
> All calculations are PLANNING AIDS ONLY, not engineering sign-off or structural certification. Verify all rigging, loads and ballasting with a certified structural engineer or licensed rigger before production. Capacities in the catalog are generic placeholder values (`"placeholder": true`). Rigging in real-world environments requires review and approval by a certified structural engineer and qualified production riggers in accordance with applicable local regulations (e.g. ANSI E1.21, DGUV 17/18, EN 17115).

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

* **Professional Dark UI Layout & Design System**:
  - **Unified Typography & Theming**: Consistent Theme hierarchy across desktop windows (body: 13-14px, small: 12px, panel headings: 16px, toolbar labels: 13px) with zero hard-coded font size overrides, scaling smoothly with display DPI.
  - **Compact Floating Viewport Toolbar**: Centered semi-transparent segmented control (`[Move  1] [Rotate  2] [Scale  3] | [World/Local] [Pivot: Base/Center] | [All Axes  X]`) with 8px padding, 4px gaps, 32px height buttons, high-contrast active accent states, and adaptive responsive text collapsing on narrow windows.
  - **Structured Properties Inspector**: Organized into clean sections (*Transform*, *Appearance*, *Rigging & Structural Loads*, *Notes*, *Actions*) with thin dividers, uniform 54px number inputs, and colored axis badges (Red = X, Green = Y, Blue = Z).
  - **Polished Catalog Cards & Status Bar**: Standardized thumbnail aspect ratios (44x44 list, 84x50 grid), refined outline-style place button, aligned star toggles, priority-based responsive status bar item collapsing, and strict 4/8/12px spacing rhythm.
  - Menu Bar (File, Edit, View, Ground, Help) with one-click `Import 3D Asset...`.
  - **Automatic HiDPI UI Scaling**: Dynamic scaling across 1080p to 4K and macOS Retina (1.0x to 3.0x in 0.25 steps) while keeping the 3D viewport rendered at native physical resolution (no blurry 3D). Verified across 100%, 150%, and 200% scaling factors with before/after visual captures in `docs/ui_polish/`.
  - Left Asset Browser with real-time search, category & subcategory filters, **Grid View** vs **List View** toggle.
  - **Favorites (★)** and **Recently Used (🕒)** equipment tabs.
  - **Persistent 3D Thumbnail Pipeline**: Dedicated offscreen SubViewport rendering 256x256 hiDPI isometric previews over neutral studio gradient backgrounds into persistent disk cache (`user://thumbnails/`), with real-time status bar progress indicator (`Thumbnails 87/147`), contact sheet generator (`docs/thumbnail_sheet.png`), and developer menu action (`View > Developer > Regenerate All Thumbnails`). Category glyph fallbacks ensure zero empty gray placeholders even when running headless.
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
* **Rigging, Load Estimation & Structural Checks Engine (Sub-phase 3A)**:
  - **Asynchronous Solver (`WorkerThreadPool`)**: Runs non-blocking statics solves in the background with 150ms debounce and thread-safe data snapshotting, keeping viewport navigation at a steady 60 FPS even with 5,000+ objects.
  - **Beam Statics Formulation**: Computes equivalent mid-span bending moments for arbitrary point loads ($P_{\text{equiv}} = P_i \frac{4 x_i (L - x_i)}{L^2}$), self-weight UDL ($P_{\text{udl}} = \frac{w L}{2}$), and support reactions. Compares total effective load against manufacturer span ratings.
  - **Live Rule Validation**: Automatically detects overloaded truss spans, overloaded hoists, overloaded towers, floating/unsupported equipment, hoists lacking load paths, mixed truss cross-section profiles (e.g. F34 vs F33), and items hung from unrated points.
  - **3D Rigging Overlay (`O` shortcut)**: Real-time 3D vector lines and labels color-coded by utilization (<60% Green, 60-90% Yellow, 90-100% Orange, >100% Red).
  - **Structural Checks Panel (`Ctrl+3` / `Cmd+3`)**: Dedicated slide-out panel with configurable safety factors (1.5:1 static structural, 5:1 rigging hardware), engineering unit toggle (`kg`, `kN`, `lb`), live severity-coded warning cards, and click-to-frame navigation in 3D.
  - **Status Bar Badge**: Live badge (`[🔴 X Critical | ⚠️ Y]` or `[✓ Rigging OK]`) with instant click access to the Checks Panel.
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
| **Move Tool (Default)** | `1` | `1` | Viewport Toolbar: **Move (1)** — 3 axis arrows + XZ ground plane handle |
| **Rotate Tool** | `2` | `2` | Viewport Toolbar: **Rotate (2)** — Single yaw ring by default |
| **Scale Tool** | `3` | `3` | Viewport Toolbar: **Scale (3)** — 3 axis box handles + uniform center |
| **Toggle All Rotation Axes** | `X` (in Rotate mode) | `X` (in Rotate mode) | Reveals pitch (X) and roll (Z) rotation rings |
| **Direct Object Dragging** | `LMB Drag` (Move tool) | `LMB Drag` (Move tool) | Click-drag body along ground plane/surface; rotation preserved 100% |
| **Direct Drag Vertical Elevate**| `Shift + LMB Drag` | `Shift + LMB Drag` | Elevates object vertically (Y-axis only) |
| **Cancel Drag Gesture** | `Esc` / `RMB` | `Esc` / `RMB` | Cancels active gizmo/direct drag, restoring initial transform |
| **Walk Move (Ground-Parallel)** | `MMB Drag` | `MMB Drag` | Middle Mouse Drag (no modifier): level ground strafe (A/D) & forward/back (W/S) |
| **Elevate View** | `Alt + MMB Drag` | `Option + MMB Drag` | Pure vertical elevation (raise/lower Y height, same as E/Q) |
| **Pan Camera** | `Alt + Shift + LMB` | `Option + Shift + LMB` | Two-Finger Trackpad Scroll / Alt + Shift + Left Mouse Drag |
| **Orbit Camera** | `Shift + MMB Drag` / `Alt + LMB` | `Shift + MMB Drag` / `Option + LMB` | Shift + Middle Mouse Drag / Option + Two-Finger Trackpad Drag |
| **Smooth Zoom** | `Ctrl + MMB Drag` | `Cmd + MMB Drag` | Smooth vertical middle-mouse drag zoom |
| **Zoom Viewport** | `Wheel Up / Down` | `Wheel Up / Down` | Two-Finger Trackpad Pinch / Mouse Wheel |
| **WASD Fly Mode** | Hold `RMB` + `WASD` | Hold `RMB` + `WASD` | `Q` (Down) / `E` (Up) / `Shift` (Boost) |
| **Top View** | `Numpad 7` | `Numpad 7` | Menu: View -> Top View |
| **Front View** | `Numpad 1` | `Numpad 1` | Menu: View -> Front View |
| **Side View** | `Numpad 3` | `Numpad 3` | Menu: View -> Side View |
| **Perspective View**| `Numpad 0` | `Numpad 0` | Menu: View -> Perspective |
| **Frame Selection** | `F` | `F` | Menu: View -> Frame Selection |
| **Select Object / Group** | `LMB` | `LMB` | Click object (clicks member selects whole group) |
| **Multi-Select** | `Ctrl + LMB` / `Shift + LMB` | `Cmd + LMB` / `Shift + LMB` | Click multiple objects |
| **Box Select** | Drag on canvas | Drag on canvas | Drag rectangle in empty space |
| **Transform Gizmo** | Drag Gizmo Handles | Drag Gizmo Handles | Isolated handles per tool mode; constant on-screen size (~110px) |
| **Rotate Selected / Ghost (Yaw Y)** | `R` (+Step) / `Shift + R` (-Step) | `R` / `Shift + R` | Rotates around Y-axis (respects 5°, 15°, 45°, 90° step) |
| **Rotate Selected / Ghost (Pitch X)** | `T` (+Step) / `Shift + T` (-Step) | `T` / `Shift + T` | Tilts vertically around X-axis with auto drop-to-surface |
| **Rotate Selected / Ghost (Roll Z)** | `Y` (+Step) / `Shift + Y` (-Step) | `Y` / `Shift + Y` | Rolls around Z-axis with auto drop-to-surface |
| **Fine Rotation Mode** | Hold `Ctrl` with `R`/`T`/`Y` | Hold `Cmd` with `R`/`T`/`Y` | Rotates in fine 5° increments |
| **Drop to Surface** | Inspector Button | Inspector Button | Snaps lowest bounding point directly onto surface (y=0) |
| **UI Scale Zoom In** | `Ctrl + Plus` (`Ctrl + =`) | `Cmd + Plus` | Steps UI scale (100% -> 300%), switches to manual |
| **UI Scale Zoom Out** | `Ctrl + Minus` | `Cmd + Minus` | Steps UI scale down to 75% |
| **UI Scale Reset to Auto** | `Ctrl + 0` | `Cmd + 0` | Resets to display-calculated automatic scale |
| **UI Scale Wheel Zoom** | `Ctrl + Wheel Up / Down` | `Cmd + Wheel Up / Down` | Adjusts UI scale when hovering over UI panels |
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
| **Toggle 3D Rigging Overlay** | `O` | `O` | Menu: View -> Rigging 3D Overlay |
| **Toggle Structural Checks** | `Ctrl + 3` | `Cmd + 3` | Menu: View -> Structural Checks |

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

### What's Done (Phase 1, Phase 2 & Sub-phase 3A Complete)
- [x] Full Godot 4.x desktop project structure with Forward+ and Compatibility fallbacks.
- [x] Python virtual environment (`.venv`) and `catalog_validator.py` with 0 errors.
- [x] 146 production equipment assets across 11 categories and 51 subcategories in `data/catalog.json`.
- [x] Procedural primitive-based 3D mesh generator with shared PBR materials for all 146 assets.
- [x] Material & color variant system (aluminum, powdercoats, flight case colors, drape fabrics) with runtime picker and undo/redo support.
- [x] GLTF / GLB asset import pipeline with polycount and scale validation, saving outside repo to `user://imported_assets/`.
- [x] Upgraded Asset Browser: Subcategories, Favorites (★), Recently Used (🕒), Grid vs. List view toggle, and cached 128x128 thumbnails.
- [x] Backward compatibility engine: seamlessly loads Phase 1 project files via legacy ID aliases.
- [x] Automated test suite with 13 comprehensive integration tests passing with 100% success rate.
- [x] Real-input simulation test harness verifying 18 critical interaction suites through the real engine event loop.
- [x] 60 FPS hold verified with 5,000 instanced objects.
- [x] **Sub-phase 3A Rigging Engine & Structural Checks**:
  - [x] Canonical rigging schema fields (`load_rating`, `swl_kg`, `motor_capacity_kg`, `is_support`, `wind_area_m2`, `drag_coefficient`, `cog_offset`, `truss_profile`) with generic editable placeholder capacities (`"placeholder": true`).
  - [x] Multi-threaded background statics solver via `WorkerThreadPool` with 150ms debounce and thread-safe data snapshotting.
  - [x] Beam statics & equivalent center-point bending formulation ($P_{\text{equiv}} = P_i \frac{4 x_i (L - x_i)}{L^2}$, UDL $P_{\text{udl}} = \frac{w L}{2}$).
  - [x] 3D Rigging Overlay (`O` shortcut) with utilization color-coding (Green/Yellow/Orange/Red).
  - [x] Structural Checks panel (`Ctrl+3` / `Cmd+3`) & Status Bar Badge with live warning cards and click-to-frame navigation.
  - [x] Engineering unit toggle (`kg`, `kN`, `lb`) and configurable static/motor safety factors.
  - [x] Prominent structural safety disclaimers across Checks panel, exported reports, and documentation.
- [x] **UI Polish & Unified Design System**:
  - [x] Global Theme font sizing and spacing (13-14px body, 12px small, 16px headings, 13px toolbar).
  - [x] Floating segmented viewport toolbar with 32px equal button heights, accent active fills, and responsive collapse.
  - [x] Properties inspector sectioning (Transform, Appearance, Rigging & Structural Loads, Notes, Actions) with colored RGB axis badges.
  - [x] Responsive status bar and tightened catalog card layout (44x44 list, 84x50 grid).
  - [x] Verified at 100%, 150%, and 200% UI scales and 1000px, 1400px, 1920px window widths with captures saved in `docs/ui_polish/`.
- [x] Comprehensive documentation in `docs/architecture.md`, `docs/rigging_math.md`, `docs/asset_pipeline.md`, and `README.md`.

### What's Next (Phase 3 Roadmap)
- [ ] **Sub-phase 3B**: Wind, ballast, overturning and sliding, Suggest Ballast, plus related rules (insufficient ballast, wind overturning risk, tall structure without guy lines).
- [ ] **Sub-phase 3C**: Line Array Designer with live curve, CoG, front/rear split, coverage wedge, cabinet count & motor capacity rules.
- [ ] **Sub-phase 3D**: Safety bonds, Load Report export (CSV + print HTML), project format update.
