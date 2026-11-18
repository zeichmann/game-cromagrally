# Third-party notices

This prototype uses **Godot Engine 4.7.2**, distributed under the MIT license.

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

The engine copyright and license statement are available at <https://godotengine.org/license/>. Godot's developers accept this link in game documentation as satisfying the engine license notice requirement.

The complete engine license, component copyright notices and third-party license texts extracted from the exact engine binary are included in [docs/GODOT_NOTICES.json](docs/GODOT_NOTICES.json). This includes notices for bundled libraries and the engine's default font. These notices apply to those components; they do not assign a license to the new game code or its content.

Keep this file and the accompanying notices when redistributing a package containing the Godot binary. `runtime/Godot.exe`, if present, is an unmodified copy of the official Windows x64 Standard editor binary used as a local development runtime. A production release should use a proper exported build.

## Jolt Physics

Vehicle contacts use the Jolt module already included in this official Godot binary. The upstream implementation uses a sequential impulse solver with warm starting and a linear shape cast for continuous collision detection. No separate physics plugin or downloaded vehicle model is required.

Sources: [Jolt Physics architecture](https://jrouwe.github.io/JoltPhysics/md__docs__architecture.html), [public implementation](https://github.com/jrouwe/JoltPhysics), [Godot integration](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html). Jolt's copyright and Expat/MIT license are retained in [docs/GODOT_NOTICES.json](docs/GODOT_NOTICES.json), extracted from the exact engine binary. These notices apply to Jolt and do not assign a license to the game code.

## Barlow fonts

`assets/fonts/Barlow-Medium.ttf` and `assets/fonts/BarlowCondensed-BlackItalic.ttf` are unmodified fonts by The Barlow Project Authors, copyright 2017, distributed under the SIL Open Font License 1.1. The complete copyright and license text is included in [assets/fonts/OFL.txt](assets/fonts/OFL.txt). Keep it with redistributed copies of the fonts.

Sources: [Barlow](https://github.com/google/fonts/tree/main/ofl/barlow), [Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed). File hashes and exact download URLs are in [docs/UI_ASSET_MANIFEST.json](docs/UI_ASSET_MANIFEST.json).

## Akademia Oli character artwork

Żabol and Świnka retain their Akademia Oli character and artwork ownership. At the user's request, the project reuses the project-created seated Żabol geometry from the local Akademia Oli chess assets and adapts it into two rigged racing characters. Świnka's face, ears, snout, costume palette and hat emblem are adapted using the existing seated illustration as the identity reference.

The original Żabol GLB, editable geometry sources, illustration references and source notices are preserved. Exact source paths, SHA-256 hashes and transformations are recorded in [docs/CHARACTER_ASSET_MANIFEST.json](docs/CHARACTER_ASSET_MANIFEST.json) and [docs/CHARACTERS.md](docs/CHARACTERS.md). The source artwork's notices are in [docs/character-sources/AKADEMIA_OLI_NOTICES.md](docs/character-sources/AKADEMIA_OLI_NOTICES.md). Reuse does not grant the characters a new open-source license.
