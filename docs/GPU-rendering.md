# GPU geometry buffers

The OpenGL compatibility renderer already performs vertex transformation,
lighting, texturing, depth testing and rasterization on the graphics driver.
Imported BG3D models and terrain patches now also keep their vertex attributes
and triangle indices in OpenGL buffer objects (`GL_STATIC_DRAW`). Each visible
mesh is uploaded once and reused across frames, instances and split-screen views.
CPU copies remain available for collision detection and bounds.

Terrain slots invalidate their buffers before being rebuilt. Scrolling model UVs
invalidate the corresponding mesh before its next draw. Mesh disposal releases
the GPU buffers; skeleton copies do not share their ownership. Skeleton deformation,
particles, text and fading fences continue to use live client arrays so their
per-frame changes are preserved. This is geometry caching, not GPU skinning or
GPU particle simulation.

Run the newly built executable with `--stats --track 1` to inspect a race.
`GPU TRIS` reports triangles drawn from resident buffers / all triangles submitted
through the mesh renderer during the preceding frame. It excludes immediate-mode
overlays and is not a percentage of GPU utilization or an FPS benchmark.

For comparison, set `CMR_DISABLE_GPU_BUFFERS=1` before launching to use the original
client-array path. Missing buffer entry points or a failed GPU allocation also
fall back to client arrays. Both paths use OpenGL to draw the scene.

Build regression checks with `-DCMR_BUILD_RENDER_TESTS=ON`, then run
`ctest --test-dir build --build-config Release --output-on-failure` (replace
`build` with your build directory). The recording-driver test checks upload reuse,
index/vertex bindings, switching to dynamic meshes, invalidation, repeated disposal,
and allocation-failure fallback without requiring a window or GPU.
