"""Original driver geometry and poses for the game's rigid joint skinning."""

from math import asin, atan2, cos, dist, pi, sin, sqrt, tau

from mesh import Mesh, add, cross, dot, ellipsoid, mul, sample_profile, sub, surface, tube, unit
from vehicle import GRIP_Y, GRIP_Z

ROOT, TORSO, HEAD, UPPER_L, LOWER_L, UPPER_R, LOWER_R = range(7)
ARMS = ((-1, UPPER_L, LOWER_L), (1, UPPER_R, LOWER_R))
BONES = (
    ("hips", -1, (0, 17, 36)),
    ("torso", ROOT, (0, 29, 38)),
    ("head", TORSO, (0, 73, 32)),
    ("shoulder.L", TORSO, (-22, 60, 30)),
    ("elbow.L", UPPER_L, (-36, 43, 4)),
    ("shoulder.R", TORSO, (22, 60, 30)),
    ("elbow.R", UPPER_R, (36, 43, 4)),
)


def grip(side):
    return (28 * side, GRIP_Y, GRIP_Z)


def make_driver():
    driver = Mesh()
    ellipsoid(driver, "tunic", (0, 23, 36), (24, 12, 20), bone=ROOT, rings=5)
    for side in (-1, 1):
        tube(driver, "tunic", [(side * 11, 25, 35), (side * 14, 24, 4), (side * 15, 19, -18)],
             [(9, 9), (9.5, 9), (7.5, 8)], bone=ROOT, sides=8)
        tube(driver, "saddle", [(side * 15, 20, -17), (side * 16, 1, -31), (side * 16, -20, -45)],
             [7.5, 7, 6.2], bone=ROOT, sides=8)
        ellipsoid(driver, "saddle", (side * 16, -21, -50), (7.7, 5.5, 12), bone=ROOT, segments=8, rings=4)

    shirt = [(29, 16, 13, 37), (35, 18, 13, 36), (48, 21, 15, 34),
             (57, 25, 14, 32), (64, 23, 12, 32), (67, 11, 9, 31)]

    def torso(u, v, offset=0):
        angle = tau * u
        y, x_radius, z_radius, z = sample_profile(shirt, v * (len(shirt)-1))
        return ((x_radius + offset) * sin(angle), y, z + (z_radius + offset) * cos(angle))

    surface(driver, "tunic", torso, 14, len(shirt)-1, bone=TORSO)
    tube(driver, "saddle", [torso(i / 24, .16, .85) for i in range(24)],
         2.5, sides=6, closed=True, bone=TORSO)

    def cape(u, v, offset=1.2):
        t = .34 + .52 * u + (1 - .34 - .52 * u) * v
        return torso(u * .51 - .15, t, offset)

    surface(driver, "blue_hide", cape, 8, 4, bone=TORSO)
    tube(driver, "thread", [cape(i / 8, .025, 1.65) for i in range(9)], .75, sides=5, bone=TORSO)
    ellipsoid(driver, "bone", (13, 60, 44), (3.2, 3.5, 1.8), segments=8, rings=4, bone=TORSO)
    tube(driver, "skin", [(0, 62, 32), (0, 75, 32), (0, 81, 32)], [9.3, 8.5, 8.8],
         sides=10, bone=HEAD)

    face = [(76, 0, 0, 34), (79, 9, 9, 31), (85, 13.5, 14, 31), (92, 17, 16, 32),
            (100, 17.8, 17, 33), (107, 15.7, 15.7, 34), (113, 11, 12, 35), (116, 0, 0, 36)]

    def head(u, v):
        y, rx, rz, z = sample_profile(face, v * (len(face)-1))
        a = tau * u
        return (rx * sin(a), y, z + rz * cos(a))

    surface(driver, "skin", head, 16, len(face)-1, poles=(0, len(face)-1), bone=HEAD)
    ellipsoid(driver, "skin", (0, 94, 15.8), (4.6, 5.4, 6.3), segments=8, rings=4, bone=HEAD)
    tube(driver, "mouth", [(-5.5, 85.0, 18.4), (0, 84.2, 16.5), (5.5, 85.1, 18.4)],
         .71, sides=5, bone=HEAD)
    for side in (-1, 1):
        ellipsoid(driver, "skin", (side * 17.2, 94, 34), (3.8, 6.3, 4.5), segments=8, rings=4, bone=HEAD)
        ellipsoid(driver, "bone", (side * 17.8, 90.8, 37), (1.7, 2.1, 1.9), segments=7, rings=4, bone=HEAD)
        ellipsoid(driver, "eye", (side * 7.3, 99, 17.5), (3.5, 1.8, 1.65), segments=8, rings=4,
                  angle=-side * .3, bone=HEAD)
        ellipsoid(driver, "hair", (side * 7.35, 99, 16.04), (1.52, 1.54, .82), segments=8, rings=3, bone=HEAD)
        tube(driver, "hair", [(side * 3.8, 103.0, 17.2), (side * 7.6, 104, 17.35),
                              (side * 11.7, 102.7, 19.8)], [1.2, 1.45, .7], sides=6, bone=HEAD)

    def scalp(u, v):
        a = tau * u
        hairline = -.34 - .65 * max(0, cos(a))**2 + .55 * max(0, -cos(a))**3 + .09 * sin(3*a)
        latitude = hairline + (pi/2 - hairline) * v
        curl = 1 + .031 * sin(7*a + 2*v) + .047 * sin(4*a - 3*v)
        return (19.3 * curl * sin(a) * cos(latitude), 102 + 17.3 * sin(latitude),
                35.8 + 18.8 * curl * cos(a) * cos(latitude))

    surface(driver, "hair", scalp, 18, 5, poles=(5,), bone=HEAD, repeat=(1, 1.5))
    tube(driver, "hair", [(0, 95, 49), (1, 87, 58), (3, 83, 63), (5, 77, 63), (7, 74, 61)],
         [7, 5.8, 4.7, 4, 1.4], sides=8, bone=HEAD)
    tube(driver, "cord", [(-3, 86, 58), (3, 88, 62), (7, 85, 59)],
         1.45, sides=6, bone=HEAD)

    for side, upper, lower in ARMS:
        shoulder, elbow = BONES[upper][2], BONES[lower][2]
        hand = grip(side)
        tube(driver, "skin", [add(shoulder, (side * 2, -1, -3)),
                              (side * 33, 50, 18), add(elbow, (0, -1, -2))],
             [8.1, 7.7, 7.1], bone=upper, sides=9)
        tube(driver, "tunic", [shoulder, (side * 27, 57, 23), (side * 31, 53, 19)],
             [(10, 9), (10.1, 9), (8.8, 8.8)], bone=upper, sides=9)
        tube(driver, "skin", [elbow, (side * 35, 45, -3), (side * 31, 51, -21), add(hand, (0, 2, 5))],
             [7.4, 7.0, 5.9, 4.6], bone=lower, sides=8)
        tube(driver, "saddle", [(side * 31, 51.6, -22), (side * 29, 54.5, -27)], [6.0, 5.7],
             bone=lower, sides=8)
        ellipsoid(driver, "skin", add(hand, (.6 * side, 3.1, 1.7)), (6.0, 6.9, 7.1),
                  segments=9, rings=5, bone=lower)
        tube(driver, "skin", [add(hand, (-side * 4, 5, 2)), add(hand, (-side * 5, 3, -2)),
                              add(hand, (-side * 4, -1, -4))],
             [2.65, 2.2, 1.4], bone=lower, sides=6)
    return driver


def transpose(matrix):
    return tuple(zip(*matrix))


def transform(matrix, vector):
    return tuple(dot(row, vector) for row in matrix)


def compose(a, b):
    return transpose(tuple(transform(a, column) for column in transpose(b)))


def rotation(x, y, z):
    sx, sy, sz = sin(x), sin(y), sin(z)
    cx, cy, cz = cos(x), cos(y), cos(z)
    return ((cy*cz, sx*sy*cz-cx*sz, cx*sy*cz+sx*sz),
            (cy*sz, sx*sy*sz+cx*cz, cx*sy*sz-sx*cz),
            (-sy, sx*cy, cx*cy))


def euler(matrix):
    return (atan2(matrix[2][1], matrix[2][2]), asin(-max(-1, min(1, matrix[2][0]))),
            atan2(matrix[1][0], matrix[0][0]))


def align(source, target):
    """Shortest rotation between two limb vectors, represented as a matrix."""
    a, b = unit(source), unit(target)
    x, y, z, w = unit((*cross(a, b), 1 + dot(a, b)))
    return ((1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)),
            (2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)),
            (2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)))


REST = (0, 0, 0)


def pose(chest=REST, head=REST, throw_grip=None):
    """Keep the hands on the steering bar as the torso leans into a turn."""
    rotations = [REST, chest, head, REST, REST, REST, REST]
    chest_rotation = rotation(*chest)
    chest_pivot = BONES[TORSO][2]
    for side, upper, lower in ARMS:
        shoulder_rest, elbow_rest = BONES[upper][2], BONES[lower][2]
        hand_rest = grip(side)
        shoulder = add(chest_pivot, transform(chest_rotation, sub(shoulder_rest, chest_pivot)))
        target = throw_grip if side == 1 and throw_grip is not None else hand_rest
        axis = unit(sub(target, shoulder))
        upper_length = dist(shoulder_rest, elbow_rest)
        lower_length = dist(elbow_rest, hand_rest)
        reach = min(dist(target, shoulder), upper_length + lower_length - .2)
        along = (reach**2 + upper_length**2 - lower_length**2) / (2 * reach)
        bend_hint = sub(elbow_rest, shoulder_rest)
        bend = unit(sub(bend_hint, mul(axis, dot(axis, bend_hint))))
        elbow = add(shoulder, add(mul(axis, along), mul(bend, sqrt(upper_length**2 - along**2))))
        hand = add(shoulder, mul(axis, reach))
        upper_world = align(sub(elbow_rest, shoulder_rest), sub(elbow, shoulder))
        lower_world = align(sub(hand_rest, elbow_rest), sub(hand, elbow))
        rotations[upper] = euler(compose(transpose(chest_rotation), upper_world))
        rotations[lower] = euler(compose(transpose(upper_world), lower_world))
    return rotations


def make_animations():
    # In PLAYER_ANIM_* order. End ticks use LOOP for driving or STOP after the release flag.
    idle = pose()
    left = pose((-.03, .07, .18), (-.022, .17, -.075))
    right = pose((-.03, -.07, -.18), (-.022, -.17, .075))
    airborne = pose((-.15, .015, .04), (.24, .012, -.02))
    spinout = pose((.12, .14, .21), (-.12, -.39, -.06))
    spinout_other_side = pose((.14, -.13, -.24), (-.12, .4, .06))
    throw_front = [
        (0, idle),
        (10, pose((.09, -.2, .07), (0, .2, 0), (44, 92, 48))),
        (16, pose((-.21, .13, -.1), (.13, -.13, .015), (27, 97, -52))),
        (29, idle),
    ]
    throw_back = [
        (0, idle),
        (9, pose((-.08, .07, -.03), (0, -.28, 0), (46, 81, -13))),
        (15, pose((.13, -.32, .13), (-.10, -.62, -.12), (56, 103, 65))),
        (31, idle),
    ]

    return (
        ("Drive", [(0, idle), (28, pose((.032, -.01, .014), (-.029, .035, -.016))), (56, idle)], [(56, 1, 0)]),
        ("Skid", [(0, spinout), (15, spinout_other_side), (30, spinout)], [(30, 1, 0)]),
        ("Turn right", [(0, right), (26, pose((-.055, -.09, -.2), (.018, -.19, .078))), (52, right)], [(52, 1, 0)]),
        ("Turn left", [(0, left), (26, pose((-.055, .09, .2), (.018, .19, -.078))), (52, left)], [(52, 1, 0)]),
        ("Jump", [(0, airborne), (17, pose((-.21, 0, -.02), (.26, .01, .025))), (34, airborne)], [(34, 1, 0)]),
        ("Accelerate", [(0, pose((.11, 0, 0))), (22, idle), (40, idle)], [(40, 1, 0)]),
        ("Brake", [(0, pose((-.19, 0, 0))), (22, idle), (40, idle)], [(40, 1, 0)]),
        ("Throw forward", throw_front, [(16, 6, 0), (29, 0, 0)]),
        ("Throw back", throw_back, [(15, 6, 0), (31, 0, 0)]),
    )
