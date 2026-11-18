"""Build the original club and the rack attached to each car."""

from math import cos, sin, tau
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "wicker_racer"))
from build_assets import write_bg3d
from mesh import Mesh, ellipsoid, tube
from vehicle import lashing


def make_club():
    club = Mesh()
    trunk = [(0, -17, 0), (0, -10, 0), (0, 14, 0), (0, 33, 1),
             (-2, 56, 1), (-5, 73, 1), (-5, 86, 1),
             (-4, 96, 0), (-3, 108, -1), (-1, 116, -1)]
    widths = [(5, 4.5), (5.5, 5), (5.9, 5.2), (7, 6), (9, 8),
              (16, 15), (26, 22), (28, 23), (21, 19), (11, 10)]
    tube(club, "frame", trunk, widths, sides=13)
    ellipsoid(club, "reed_dark", (8, 89, 17), (9, 8, 7), segments=8, rings=4)
    ellipsoid(club, "frame", (-21, 80, 5), (9, 8, 8), segments=8, rings=4)
    lashing(club, (0, 1, 0), (0, 1, 0), 5.9, 22, 7)
    lashing(club, (-2, 52, 1), (0, 1, 0), 8, 6, 3)
    return club


def make_rack():
    rack = Mesh()
    tube(rack, "frame", [(-39, -24, 0), (-25, -19, 0), (-13, -16, 0), (-5, -16, 0)], [4.8, 4.4, 3.6, 2.8])
    tube(rack, "frame", [(-24, -33, 3), (-14, -24, 1), (0, -18, 0)], [4.0, 3.8, 3.3])
    cradle = [(7.8 * cos(tau*i/20), -10, 7.8 * sin(tau*i/20)) for i in range(20)]
    tube(rack, "saddle", cradle, 2.3, sides=7, closed=True)
    lashing(rack, (-19, -18, 0), (1, 0, 0), 4.5, 9, 3)
    return rack


if __name__ == "__main__":
    models = Path(__file__).resolve().parents[2] / "Data" / "Models"
    write_bg3d(models / "DriverClub.bg3d", [make_club(), make_rack()])
