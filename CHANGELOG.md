# Changelog

All notable changes to this fork of [Pixal3D](https://github.com/TencentARC/Pixal3D) are documented here.
Original work by Dong-Yang Li, Wang Zhao, Yuxin Chen, Wenbo Hu, Meng-Hao Guo, Fang-Lue Zhang, Ying Shan, and Shi-Min Hu (Tsinghua University / Tencent ARC Lab).

---

## [Fork.2] — 2026-05-19

### Critical mesh quality fix: Full Fidelity extraction mode

**Background — how the pipeline actually produces geometry**

Pixal3D uses a *Flexible Dual Grid* representation internally. During training, the model learns to place one vertex per occupied sparse voxel at a position determined by `(grid_coord + dual_vertex_offset) × voxel_size`. The `dual_vertex_offset` is a three-channel feature decoded by the neural network and represents a *learned sub-voxel displacement* — the model has encoded exactly where on the isosurface each vertex should sit. This is the highest-fidelity geometric output the network is capable of producing.

The mesh that comes out of `pipeline.decode_latent()` therefore already contains full model precision: adaptive polygon density (more faces where the surface is geometrically complex, fewer where it is flat — both intentional and correct) and vertex positions that reflect what the network actually learned.

**What the original pipeline was doing instead**

`to_glb()` was called with `remesh=True`, which immediately discarded this decoded mesh and rebuilt topology from scratch using Dual Contouring (DC) on a 96-cell grid (1536 ÷ 16 = 96). DC places one vertex per active grid cell near the surface — it has no knowledge of the model's learned `dual_vertex_offset`. The only connection back to the original surface is the `project_back` parameter, which was additionally set to `0` in our codebase (see the earlier `remesh_project` fix), so even that correction wasn't applied.

The visible result: large flat triangular facets in smooth regions of the mesh (torso, arms, broad clothing surfaces) coexisting with fine detail in geometrically complex regions (cloth folds, creases). DC generates more cells where more surface voxels are active — complex areas get dense geometry, flat areas get almost nothing. Applying smooth shading to this topology creates the characteristic look of a low-poly mesh with a smoothing modifier — shade gradients are correct but the silhouette and surface under close inspection reveal the underlying faceted geometry.

Critically, the decimation slider had no meaningful effect in this mode. The DC mesh on a typical full-body character at 1536 resolution produces roughly 200K–500K faces. Setting the slider to 5M faces only prevented further reduction of a mesh already below that limit — it could not add geometry that DC never created.

**The fix**

- `remesh` parameter changed from hardcoded `True` → user-selectable, default `False` (**Full Fidelity** mode).
- In Full Fidelity mode, `to_glb()` receives `remesh=False`. The FlexiDualGrid mesh is kept as-is, passed through topology cleanup (remove duplicate faces, repair non-manifold edges, fill small holes, unify orientation), then UV-unwrapped and texture-baked normally. The model's learned vertex positions are fully preserved.
- DC Remesh mode (`remesh=True`) is still available via the **Mesh Mode** dropdown for workflows that specifically need clean quad-dominant topology (e.g. retopology base meshes, sculpting targets).
- Added `verbose=True` to `to_glb()` so face counts at each processing stage are logged, making it straightforward to see the actual polygon count the model produced and verify the simplification ceiling is not being hit.
- **Max Faces** slider renamed from "Max Vertices" — the `decimation_target` parameter is a face count, not a vertex count. The earlier label was incorrect.

**Why this matters**

The difference between Full Fidelity and DC Remesh is not subtle — it is the difference between the model's actual output and a geometric approximation of it. For assets going into a rendering pipeline, VFX production, or anywhere geometric accuracy matters, Full Fidelity preserves everything the network learned. DC Remesh was a reasonable default for the original HuggingFace Spaces demo (where clean downloadable topology mattered more than extraction fidelity) but is the wrong default for a local high-quality workstation setup.

---

## [Fork.1] — 2026-05-19

### Bug Fixes

**Preview frames black after generation**
- Root cause: `FileData` objects inside a plain `dict` return from `generate_3d` were serialised by Gradio as Python repr strings (`"path='...' url=None ..."`) rather than proper JSON, because Gradio's `traverse()` / `is_file_obj_with_meta()` only matches pre-serialised dicts, not live Pydantic model instances.
- Fix: changed `mode_files.append(FileData(path=p))` → `mode_files.append(FileData(path=p).model_dump())` throughout `generate_3d`. Gradio can now process the nested file objects correctly, copies them to its cache, and populates the `url` field.

**3D viewer blank after GLB extraction**
- Root cause: same serialisation issue; the `extract_glb_api` return value was also passing a raw `FileData` instance that did not get a `url` set by Gradio.
- Fix: changed return type to `dict` and pre-serialised all `FileData` values with `.model_dump()`.

**`/gradio_api/file=` returning 403 for render files**
- Fix: added `allowed_paths=[TMP_DIR]` to `app.launch()` so Gradio serves files from the custom temp directory.

### Quality Improvements

**Increased voxel resolution cap (`CASCADE_MAX_NUM_TOKENS`)**
- Changed from `49152` → `131072`.
- The pipeline decrements `actual_hr_resolution` by 128 (1536 → 1408 → 1280 → …) until token count fits `max_num_tokens`. At 49152 the model fell back to 1280 for most objects; at 131072 it consistently stays at 1536 — the model's trained maximum.

**Fixed `remesh_project=0` (mesh quality)**
- The call to `o_voxel.postprocess.to_glb` had `remesh_project=0`, overriding the library's own default of `0.9`.
- At `0`, Dual Contouring places every vertex exactly on the voxel grid boundary, producing stairstepped blocky topology regardless of resolution.
- Fix: restored to `remesh_project=0.9` so vertices are projected back to the smooth isosurface.

**Exposed quality sliders: Shape Steps, Texture Steps, Texture Size**
- Shape Steps (default 20, range 1–50): diffusion steps for the high-resolution shape SLaT refinement pass. Was hardcoded to 12.
- Texture Steps (default 20, range 1–50): diffusion steps for PBR texture generation. Was hardcoded to 12.
- Texture Size (2048 / 4096 / 8192, default 8192): UV texture atlas resolution passed to `extract_glb_api`. Was hardcoded to 4096.

**Max Vertices slider extended to 5 million**
- Previous range capped at 1,000,000 vertices (~2M triangles), which silently capped DC remesh output for complex high-resolution objects.
- Extended range: 1,000 – 5,000,000 vertices with direct numeric entry field.

### New Features

**OBJ export**
- Added `_build_obj_zip()` helper and updated `extract_glb_api` to also produce an OBJ + MTL + textures ZIP alongside the GLB.
- A **Download OBJ** button appears at step 3 after extraction completes. Falls back gracefully: if OBJ export fails for any reason, GLB download is unaffected.

### UI / UX Overhaul

**Editable numeric fields on every slider**
- Every `<input type="range">` now has a paired `<input type="number">` that syncs bidirectionally. Type exact values directly (e.g. `5000` for a game-ready low-poly mesh).
- `syncRange(id)` / `syncNum(id)` JS helpers replace the old read-only `updateVal` display approach.

**Descriptions and tooltips on all controls**
- Every control in Base Settings and Advanced Engine has:
  - A `title` attribute (browser tooltip on hover)
  - A `.ctrl-hint` paragraph below explaining what the parameter does, its meaningful range, and the trade-offs
- Controls covered: Target Resolution, Seed, Camera FOV, SS Guidance, SS Steps, Shape Guidance, Shape Steps, Texture Steps, Texture Size, Max Vertices.

**Target Resolution option labels updated**
- "1024 (Balanced)" → "1024 — Balanced / Faster"
- "1536 (High Quality)" → "1536 — Maximum Detail"
- Hint text clarifies that 1536 is a model architecture ceiling, not a VRAM choice.

**Texture Size: added 2048 option**
- Added `2048 — Fast / Small file` option for quick iteration exports.
