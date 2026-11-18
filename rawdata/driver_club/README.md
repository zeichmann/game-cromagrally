# Driver club

Run `python -B rawdata/driver_club/make_club.py` from the repository root to regenerate the club and rack in `Data/Models/DriverClub.bg3d`.

The grip is at the origin and the club extends along local +Y. The club head's
contact sphere in `Source/Player/Player_Club.c` follows the thick end of the model.
It is swept against the animated head of each other driver during the downswing.
