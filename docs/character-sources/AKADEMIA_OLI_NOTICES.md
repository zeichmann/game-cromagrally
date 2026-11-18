# Third-party code

## Sculpted Żabol model — 2026-10-19

`assets/pirate/models/zabol-seated-v1.glb` is a project-created, seated 3D interpretation of the existing Akademia Oli Żabol character. It is built from editable geometry in `./provenance/design/board-3d/zabol-model.js`, `zabol-hat.js` and `zabol-outfit.js`, with the existing seated illustration used as the identity reference. The head, mouth cavity, eyes, hat, anchor, clothing, hands, boots and chair are dimensional meshes; no character image plane or embedded illustration is used in the model. Character and branding ownership remain with Akademia Oli as described below.

The model is exported as glTF 2.0 binary using Three.js 0.180.0 (MIT), loaded as a version-pinned package for the design preview and export tools. Three.js project and license: https://github.com/mrdoob/three.js/blob/r180/LICENSE. The generated GLB contains geometry and materials and does not embed the Three.js runtime.

## Local English pronunciation — 2026-10-12

`assets/english/audio-v1/*.wav` are 196 locally generated teaching recordings made with the installed Microsoft Zira Desktop (`en-US`) voice through Windows `System.Speech`. Their source scripts come from the project's English learning cards, opening lessons and factual move descriptions. Playback uses ordinary local PCM WAV files and requires no installed speech voice or remote speech service.

`scripts/generate-english-audio.ps1` records 22,050 Hz, 16-bit mono audio, trims exact zero-valued edge silence with 80/120 ms margins, and reads square names as letter plus number. `assets/english/audio-v1/manifest.json` preserves every displayed/spoken script, recording setting, duration, PCM validation result and SHA-256. Existing recordings are verified and never overwritten by the generator.

## Living characters and scenery — 2026-10-12

`assets/pirate/characters/{swinka,zabol}-blink-v3-{half,closed,gaze}.png` are six transparent animation sheets generated with the built-in `image_gen.imagegen` tool, using each character's v2 expression sheet as the edit reference. The corresponding lossless WebP files decode to identical RGBA pixels. Exact prompts, references and the sprite layout are saved in `assets/pirate/characters/blink-v3.prompts.json`; all original PNGs are preserved.

The runtime composites only feathered eye masks from the generated sheets over the v2 portraits. Local chest and inner-face movement reuse the existing v2 artwork. Living scenery uses original project-local SVG/CSS masks and animation over the existing cabin and chapter illustrations, with no external image service at runtime. These derivative character illustrations retain the Akademia Oli artwork ownership described below.

## Captain's cabin visual polish — 2026-10-11

`assets/pirate/captains-cabin-v2.png` is a new background illustration made with the built-in `image_gen.imagegen` tool, using the existing Akademia Oli `cabin.webp` as a visual reference. The game consumes `captains-cabin-v2.webp`, an optimized encoding at the original dimensions. Its exact prompt and reference are recorded in `assets/pirate/generated-premium-20261011.json`.

`assets/pirate/characters/{swinka,zabol}-emotions-v2.png` are generated transparent expression sheets made with the same built-in tool, using the corresponding seated v1 illustrations as identity references. The game uses lossless WebP copies with identical dimensions and alpha. Exact prompts, alpha verification and sprite layout are recorded in `assets/pirate/characters/emotions-v2.prompts.json`. These derivative illustrations preserve the Akademia Oli characters' ownership and do not acquire the source game's GPL license. The v1 artwork remains available as a fallback.

The nautical SVG icons, refined captain-piece SVGs, ship, seal and souvenir gradients are original project-local code artwork. All text, buttons, board squares and game state remain independently rendered HTML/SVG.

- Original Chess Html project: https://github.com/99fk/chess-html — GPL-3.0 (see LICENSE).
- Bundled Stockfish engine remains unchanged, under GPL-3.0, as distributed by the original project.
- chess.js 1.4.0: https://github.com/jhlywa/chess.js — BSD-2-Clause; full notice in vendor/chess.LICENSE. The browser ES module is vendored locally from https://unpkg.com/chess.js@1.4.0/dist/esm/chess.js.

The interface, SVG pieces and interaction code are local additions. No Chess.com assets are included.

`assets/pirate/openings/{evans,lopez,reti}-v1.png` and `assets/pirate/ui/plank-{gold,teal}-v1.png` were generated with the built-in ImageGen tool on 2026-10-11. Exact prompts and original output paths are in `assets/pirate/generated-20261011.json`. Portraits are fairytale interpretations inspired by William Davies Evans, Ruy López de Segura and Richard Réti, not authenticated historical likenesses. Labels and controls remain accessible HTML over the generated wooden backgrounds.

`assets/pirate/openings/{greco,staunton,morphy,capablanca}-v1.png` and `assets/pirate/ui/scroll-{card,wide}-v1.png` were generated with the built-in ImageGen tool on 2026-10-11. Exact prompts and original output paths are in `assets/pirate/generated-scrolls-20261011.json`. The four portraits are artistic historical interpretations used as course mentors, not claims about authorship or the origin of geographical opening names. The blank scroll artwork contains no rendered text; all content remains live HTML.

`assets/pirate/fairytale/{harbor,parrot,chest}-v1.png` reuse the illustrations generated for the approved child UI project. Their prompts and provenance are in `./provenance/design/child-ui-v1/asset-manifest.json`. Opening names, positions and brief biographical context are checked against the sources listed in `opening-content.js`; no remote pictures or copied biographies are bundled.

`assets/pirate/atlas-compass.svg` is an original decorative vector drawing for the cabin panel. The shared panel and dialog skins reuse the Akademia Oli frame and timber assets credited below.

`assets/pirate/archipelago-map-v1.png` is an original map illustration generated with the built-in imagegen tool on 2026-09-27. The prompt is recorded in `./provenance/design/campaign/map-art-prompt.md`. Island buttons, route progress and labels are rendered separately in HTML/CSS/SVG.

## Akademia Oli theme

`assets/pirate/characters/swinka-seated-v1.png` and `zabol-seated-v1.png` are transparent seated-character illustrations created with the built-in image_gen tool on 2026-09-27, using the supplied Świnka and Żabol avatar artwork as identity references. The exact prompts and reference paths are recorded in `./provenance/design/campaign/character-art-prompts.md`. These illustrations are separate from the live chessboard and pieces.

The pirate graphics in `assets/pirate/` are copied from the user-supplied `C:/___www_AkademiaOli` project:

- `cabin.webp`: `public/swinka-journal-v1/desk.webp`.
- `frame.webp`, `title.webp`: `public/swinka-game-scene-v1/crew-board.webp`, `title-sign.webp`.
- `swinka.webp`, `zabol.webp`: `public/swinka-game-premium-v2/avatar-swinka.webp`, `avatar-zabol.webp`.
- `wood-dark.webp`, `wood-light.webp`: `public/ui-buttons/pirate-button-primary-premium.webp`, `pirate-button-secondary-premium.webp`.
- `ribbon.png`: `design/game-concept-2026-09-21/journal-implementation/ribbon-source.png`.
- `PirataOne-Regular.ttf` and `OFL.txt`: `public/swinka-journal-v1/` (SIL Open Font License).

Academia Oli branding and artwork retain their original ownership; reuse here does not assign them the chess source code's license. Assets are served locally; no connection to the original project is required.

`board-frame-v2.png` is a new square frame generated with the built-in ImageGen tool, using `wood-dark.webp` as a material reference. The exact generation prompt is saved in `assets/pirate/board-frame-v2.prompt.txt`. This generated derivative uses the same Akademia Oli visual direction; it is not an asset from the original Chess Html project.

`captains-desk-v1.png` was generated with the built-in ImageGen tool using the approved `./provenance/design/ui-options/05-stol-kapitana.png` concept as reference. It contains background art only; the board, figures, notebook, binding rings, controls and text are rendered separately by the app. The exact prompt is saved in `assets/pirate/captains-desk-v1.prompt.txt`.

`assets/pirate/scenes/chapter-02-v1.png` through `chapter-08-v1.png` are chapter scenery illustrations generated with the built-in image_gen tool on 2026-09-27. Exact prompts and references are recorded in `./provenance/design/campaign/scenery-prompts-02-04.md`, `scenery-prompts-05-07.md`, and `scenery-prompts-08.md`. They contain background artwork only and do not define chessboard squares, pieces or game rules. Chapter 1 reuses `captains-desk-v1.png`.

## Corresponding Stockfish source in this production package

The supplied JavaScript and WebAssembly match upstream ddugovic-250718 at commit 29babbba8f681739189b2f565575c6da319ebecc. The complete exact-commit source archive, checksums, artifact comparisons and original build instructions are included in [licenses/STOCKFISH-SOURCE.md](licenses/STOCKFISH-SOURCE.md). The original distributed engine files and notices are unchanged.
