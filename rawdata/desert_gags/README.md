# Desert spectators and wheel dust

Run `python rawdata/desert_gags/build_assets.py` from the project root to rebuild
`Data/Models/DesertGags.bg3d` and `Data/Sprites/wheeldust.png` using the Python
standard library. The sprite uses the matching `wheeldust.txt` atlas entry.

The model order follows the desert gag object types in `Source/Headers/mobjtypes.h`.
The scene locations and animation pivots are in `Source/Items/DesertGags.c`.
