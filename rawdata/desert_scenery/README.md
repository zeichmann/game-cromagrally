# Desert cliffs and dunes

The built-in ImageGen tool generated `Data/TexturesHD/desert-fractured-rock.png`.
The terrain shader projects it in world space and blends it with the sandstone
material based on the slope.

`Source/Terrain/DesertDunes.c` defines the dune locations and profiles. The game
adds their heights to the Desert height grid at load time. Wheel contact and
terrain rendering read the same grid.

## ImageGen prompt

> Use case: stylized-concept. Create one square, seamlessly repeating diffuse texture tile for a 3D game's steep desert canyon walls. Straight-on orthographic surface fill, edge to edge. Natural fractured sandstone with irregular angular interlocking slabs, thin jagged cross-cutting cracks, chipped edges, eroded granular pits and sparse short sediment traces. Sun-baked ochre and muted terracotta with warm taupe in the crevices. Detailed rock grain, convincing geology and restrained contrast that reads at racing distance. Use even neutral lighting, with only subtle contact shadows in cracks. The texture must repeat in two axes. Avoid masonry joints, regular bands, round pebbles, dramatic baked highlights, perspective, sky, ground, plants, borders and text.
