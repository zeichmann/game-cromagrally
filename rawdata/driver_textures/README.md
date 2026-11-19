# Driver textures

The built-in ImageGen tool generated `Data/TexturesHD/driver-hide-detail.png`.
`Source/3D/DriverTextures.c` uses its grain when expanding the 256 × 256 driver
atlases to 1024 × 1024. This covers the original standing models and the twelve
color variants shared by the character picker, vehicle picker, and race. The
new texture levels use mipmaps for distant views. `CMR_ORIGINAL_TEXTURES=1`
selects the original atlases.

## ImageGen prompt

> Use case: game material texture. One square tile of dry, soft, slightly fibrous hand-worked buckskin suede in warm neutral taupe, for color-independent luminance detail on stylized prehistoric racing outfits. Flat frontal macro view, soft uniform neutral diffuse lighting. Mid-value broad mottling is extremely subtle. Readable micro pores, fine velvety interwoven hide fibers with irregular very shallow grain marks on multiple fine scales, natural handcrafted animal hide material. No holes, stitches, seams, large folds, spots, directional shadows, scratches, borders, objects, characters, text or decorative markings. Texture fills all pixels and is seamless on both axes. It will be composited over the game's existing dyed costumes.
