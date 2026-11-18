# Wicker Racer

Rebuild the Wicker Racer model with Python 3.9 or later from the repository root.

```shell
python -B rawdata/wicker_racer/build_assets.py
```

- `vehicle.py` defines the wicker body, bentwood frame, painted hide panels and four wheels. The wheel meshes rotate around their local X axes. Keep the `WHEEL_CENTERS` values in sync with the `CAR_TYPE_WICKER` offsets in `Source/Player/Player_Car.c`.
- `materials.py` defines the procedural color textures. `build_assets.py` writes the BG3D model.
- The selected Brog or Grag model sits at the offsets in `AlignCarDriver`. The same placement is used in the vehicle preview and race.

Wicker Racer is the last choice in the land vehicle menu. To start a practice race on the desert track directly, launch the game executable with `--track 1 --car 12`.
Add `--hide-hud` to start with the race HUD hidden. Scroll Lock toggles it during the race.
