# Changelog

All notable changes to this fork of [Pixal3D](https://github.com/TencentARC/Pixal3D) are documented here.
Original work by Dong-Yang Li, Wang Zhao, Yuxin Chen, Wenbo Hu, Meng-Hao Guo, Fang-Lue Zhang, Ying Shan, and Shi-Min Hu (Tsinghua University / Tencent ARC Lab).

---

## [Fork] — 2026-05-19

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
