# High-resolution material pack

Created with the built-in ImageGen tool for this project. Original assets remain
in `Data/Sprites/Fences`; the loader selects these sibling replacements by default.
Requested sizes were generation guidance; actual delivered sizes are below.

| Asset | Actual resolution | Use |
| --- | --- | --- |
| `Fences/desertskin.png` | 1254 x 1254 RGBA | Spotted hide and timber fence |
| `Fences/rockwall.png` | 1774 x 887 RGBA | Low and tall dry-stone walls |
| `Fences/aztec.png` | 2172 x 724 RGB | Ornate golden stone fence |
| `desert-detail.png` | 1254 x 1254 RGB | Repeating grayscale desert surface detail |

Fence references were the corresponding original textures. Transparent areas were
preserved for hide and stone wall. The final Aztec iteration removed unwanted white
margins. Terrain detail was generated from text. No artificial upscale was used.
See [prompts.md](prompts.md) for the final prompt set.

Filtering uses mipmaps and up to 16x anisotropy, subject to driver support. Fence UV
scaling uses the material's actual aspect ratio. Set `CMR_ORIGINAL_TEXTURES=1` to
compare original assets.
