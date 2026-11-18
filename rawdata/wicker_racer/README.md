# Wicker Racer

The vehicle and its driver are original 3D assets. Rebuild the three checked-in game assets with Python 3.9 or later from the repository root.

```shell
python -B rawdata/wicker_racer/build_assets.py
```

- `vehicle.py` defines the wicker body, bentwood frame, painted hide panels and four wheels. The wheel meshes rotate around their local X axes. Keep the `WHEEL_CENTERS` values in sync with the `CAR_TYPE_WICKER` offsets in `Source/Player/Player_Car.c`.
- `driver.py` defines the seated driver, seven joints and the poses used by the in-game animation states. The driver's grip targets match the steering bar in `vehicle.py`.
- `materials.py` defines the procedural color textures. `build_assets.py` writes BG3D geometry and the resource fork that binds the driver mesh to its joints.

Wicker Racer is the last choice in the land vehicle menu. To start a practice race on the desert track directly, launch the game executable with `--track 1 --car 12`.
