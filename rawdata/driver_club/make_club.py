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
             (-2, 57, 1), (-4, 91, 2), (-7, 117, 1), (-6, 139, 0),
             (-4, 161, 0), (-1, 179, -2), (1, 190, -3), (2, 197, -3)]
    widths = [(5, 4.5), (5.5, 5), (5.9, 5.2), (7, 6), (9, 8),
              (13, 11), (23, 20), (37, 32), (41, 36), (36, 31), (26, 22), (12, 11)]
    tube(club, "frame", trunk, widths, sides=20)
    ellipsoid(club, "reed_dark", (14, 154, 30), (11, 13, 9), segments=12, rings=6)
    ellipsoid(club, "frame", (-34, 144, 6), (11, 11, 10), segments=12, rings=6)
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
