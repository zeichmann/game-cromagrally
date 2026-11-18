# GPU rendering and simulation

The OpenGL compatibility renderer keeps models, terrain, skinned meshes and particle geometry in vertex/index buffers. Static meshes upload once. Terrain slots and edited UVs invalidate their caches. CPU copies remain available for gameplay and compatibility fallback.

## Compute backend

Windows and Linux request an OpenGL 4.3 compatibility context, falling back to the original 2.0 context. macOS retains its legacy context. On a capable driver:

- `Data/Shaders/skin.comp` transforms bone-relative positions and normals directly into mesh VBOs. Reference geometry uploads once per skeleton type; only the joint matrix palette changes per draw. Shared source normals are transformed separately for each attached bone. Animated vertices are not read back during normal rendering.
- `particles.comp` integrates gravity, rotation, movement, gravitational attraction, terrain contact/reflection, scale decay and alpha decay. It samples the uploaded height/split map using the same triangle convention as gameplay. State is read back for CPU damage/extinguishing checks and emitter slot reuse. This synchronous readback remains a cost; no FPS improvement is claimed. Gravitoids use an immutable previous-state snapshot, replacing order-dependent updates and the old group/particle distance-cache indexing bug. Minor trajectory differences are expected.
- `billboards.comp` builds camera-facing quads and packed colors directly in GPU buffers for each viewport. Empty slots produce transparent degenerate quads.

Animation timing, event dispatch, joint hierarchy evaluation, gameplay collisions and emission remain on CPU. This is GPU skinning and particle simulation, not migration of the entire game simulation.

Unsupported hardware, shader compiler errors and runtime compute errors select the CPU path. Cached output is released before CPU rendering resumes. Mesh, level and context cleanup release their buffers/programs.

## Artwork

Four ImageGen assets live in `Data/TexturesHD`. Hide, stone-wall and Aztec textures replace selected fences. The desert track uses an additional detail layer projected along all three world axes so it follows both the road and the cliffs. The detail textures use trilinear mipmaps and up to 16x anisotropic filtering. Devices with texture limits below 4096 use the original artwork.

The terrain renderer sharpens magnified texels in the original tiles. The inset tile borders keep their shared blend, and pixels viewed at a distance use standard bilinear sampling. The fixed-function renderer is available on drivers without terrain shader support.

## Diagnostics and tests

Build normally (`BUILD.md`). Launch the new executable with `--stats --track 1` for desert or `--stats --track 3` for ice. `GPU` reports buffered/all submitted mesh triangles, then `V` (GPU-deformed vertices) and `P` (GPU-simulated particles). Submitted triangles include empty particle slots and exclude immediate-mode overlays; they are not GPU utilization or visible-triangle percentages.

Use **Options → Graphics → Sharpness** to adjust terrain sampling and the screen
filter live. During a race, open **Settings → Graphics** from the pause menu.
The range is 0–100%. At 0%, the original tiles use linear sampling and the
screen filter is off. The default is 65%, and the chosen value is saved in your
preferences.

Environment switches, set before launch:

- `CMR_DISABLE_GPU_COMPUTE=1`: CPU skinning/simulation, resident static geometry.
- `CMR_DISABLE_GPU_BUFFERS=1`: original client arrays and CPU computation.
- `CMR_ORIGINAL_TEXTURES=1`: original artwork, no terrain detail layer.
- `CMR_DISABLE_SHARPENING=1`: turn off terrain and frame sharpening for the session.
- `CMR_VALIDATE_GPU=1`: also compute the CPU skinning reference and compare every pose with actual GPU output. Logs the first pass per skeleton type; exits 3 on mismatch. Disable for regular play.
- `CMR_COMPUTE_SELFTEST=1`: real-driver numerical tests, then exit. Tests transforms, gravity/decay/rotation, both terrain splits and bounce, inactive/dead particles, gravitoid symmetry, billboard geometry and packed alpha.

With `-DCMR_BUILD_RENDER_TESTS=ON`, run `ctest --test-dir build-gpu --build-config Release --output-on-failure` (substitute your build directory). The recording-driver lifecycle test needs no GPU. The numerical test opens a GL context; it skips with exit 2 when unsupported and fails on numerical/compiler errors. An interactive display is required for that test.
