# Stage-Builder 3D Asset Import Pipeline

This guide outlines how to import any 3D equipment model (GLTF / GLB format) into Stage-Builder in **5 minutes**, assigning real-world dimensions, physical weights, and snap points without writing code.

---

## 1. Prerequisites & Specifications

| Property | Rule |
| :--- | :--- |
| **File Format** | Binary `.glb` (recommended) or `.gltf` (with embedded/packaged textures). |
| **Scale Rule** | **1 Godot unit = 1 meter**. Ensure your DCC tool (Blender, Maya, Cinema 4D) exports with 1 unit = 1m. |
| **Pivot / Origin** | Place the object pivot at its geometric center or base (e.g. on the ground for floor equipment, or at mounting clamps for flown fixtures). |
| **Recommended Polycount** | Low-to-medium poly (under 50,000 triangles per asset). Stage-Builder warns if > 150,000 triangles. |
| **Materials** | Standard PBR (Albedo, Roughness, Metallic, Normal, Emission). |

---

## 2. Step-by-Step 5-Minute Import Walkthrough

### Step 1: Open the Import Wizard
1. Launch **Stage-Builder**.
2. Click **File > Import 3D Asset (GLTF/GLB)...** from the top menu bar.
3. Browse and select your `.glb` or `.gltf` file.

### Step 2: Review Automatic Geometry Inspection
Stage-Builder's import inspector immediately analyzes the file and displays:
* Total Triangle & Vertex Count.
* Source Bounding Box Dimensions (Width, Height, Depth).
* Scale Warnings (alerting if the model is larger than 500m or smaller than 0.005m).

### Step 3: Configure Metadata
In the dialog fields:
1. **Name**: Enter a clean industry name (e.g. `Touring Beam Moving Head`).
2. **Category**: Choose from the 11 standard production categories (Truss, Staging, Audio, Lighting, Video, Power, DJ & Backline, Rigging, Roof & Structure, Environment, Crowd).
3. **Subcategory**: Specify a subcategory (e.g. `Moving Heads`, `Subwoofers`, `Decks`).
4. **Dimensions (Meters)**: Adjust X, Y, and Z if necessary.
5. **Weight (kg)**: Enter the physical weight (used for live stage load calculations).
6. **Tags**: Add comma-separated keywords for live search (e.g. `beam, 300w, moving head, dmx`).

### Step 4: Add Snap Points (Optional)
To enable magnetic snapping to truss pipes, stage decks, or tower spigots:
1. Click **+ Add Snap Point**.
2. Enter the compatible snap tag:
   * `truss_f34` (standard 290mm box truss)
   * `truss_f33` (triangle truss)
   * `tower_mast` (ground support mast)
   * `deck_edge_1m` or `deck_edge_2m` (stage deck edges)
   * `barrier_side` (crowd control barriers)
   * `hoist_top_hook` or `hoist_bottom_hook` (rigging hoists)
3. Set the local offset coordinates `(X, Y, Z)` relative to the object's origin.

### Step 5: Click "Import & Register"
* Stage-Builder copies the model into your persistent user library at `user://imported_assets/` (outside the repo).
* Registers the metadata into `user://imported_catalog.json`.
* The asset instantly appears in the Left Asset Catalog Browser and is immediately ready to place!

---

## 3. Storage Architecture

User-imported assets are stored outside the source code repository in Godot's persistent application data directory:
* **Windows**: `%APPDATA%\Godot\app_userdata\Stage-Builder\imported_assets\`
* **macOS**: `~/Library/Application Support/Godot/app_userdata/Stage-Builder/imported_assets/`

The catalog index is saved as `user://imported_catalog.json`. When Stage-Builder launches, it automatically merges the core catalog and user catalog into a single unified library.

