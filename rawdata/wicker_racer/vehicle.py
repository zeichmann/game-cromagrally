"""Wicker Racer body, wheel meshes and rest-pose showroom assembly."""

from math import cos, pi, sin, tau

from mesh import Mesh, add, cross, ellipsoid, mul, surface, tube, unit, wheel_ring

# Front left, front right, rear right, rear left, as in Player_Car.c.
WHEEL_CENTERS = ((-105, -34, -100), (105, -34, -100), (109, -31, 98), (-109, -31, 98))
GRIP_Y, GRIP_Z = 49, -37


def lashing(mesh, center, axis, radius, length, turns, material="cord"):
    axis = unit(axis)
    hint = (0, 1, 0) if abs(axis[1]) < .8 else (0, 0, 1)
    radial = unit(cross(axis, hint))
    tangent = cross(axis, radial)
    path = []
    for i in range(turns * 10 + 1):
        t = i / (turns * 10)
        angle = tau * t * turns
        offset = add(mul(radial, radius * cos(angle)), mul(tangent, radius * sin(angle)))
        path.append(add(center, add(offset, mul(axis, (t - .5) * length))))
    tube(mesh, material, path, 1.65, sides=6)


def basket(t, angle, offset=0):
    """The basket flares from a narrow floor into an oval, higher at the back."""
    back = cos(angle)
    x_radius = (44 + 34 * t) * (1 + .14 * back)
    z_radius = 76 + 58 * t
    height = -42 + t * (80 + 7 * cos(2 * angle) + 8 * back)
    return ((x_radius + offset) * sin(angle), height, (z_radius + offset) * back)


def apron(mesh, material, mid, half_width, depth):
    def cut(u, v, offset=5.4):
        angle = mid + (2 * u - 1) * half_width
        low = 1 - depth * (1 - .43 * (2 * u - 1)**2)
        return basket(low + v * (1.012 - low), angle, offset)

    surface(mesh, material, cut, 20, 8)
    hem = [cut(i / 20, 0) for i in range(21)]
    tube(mesh, "saddle", hem, 1.4, sides=6)
    for i in range(1, 24):
        u = i / 24
        tube(mesh, "thread", [cut(u - .008, .035, 5.95), cut(u + .008, .12, 6.1)], .57, sides=5)


def make_body():
    body = Mesh()
    surface(body, "basket_lining", lambda u, v: basket(v, tau * u, -2.1), 72, 10)
    surface(body, "basket_lining", lambda u, v: basket(v, tau * u, -3.0), 72, 10, reverse=True)
    ellipsoid(body, "saddle", (0, -40, 0), (48, 5, 82), segments=36, rings=8)
    ellipsoid(body, "saddle", (0, 15, 39), (33, 7, 29), segments=24, rings=8)
    ellipsoid(body, "saddle", (0, 29, 65), (34, 19, 8), segments=24, rings=8)
    tube(body, "frame", [(-39, 7, 48), (0, 7, 48), (39, 7, 48)], 5.2)

    stakes = 40
    for i in range(stakes):
        angle = tau * i / stakes
        path = [basket(j / 8, angle + .018 * sin(pi * j / 8)) for j in range(9)]
        material = "reed_light" if i % 5 == 0 else "reed"
        tube(body, material, path, [(2.15 + j * .048, 2.0) for j in range(9)],
             sides=6, caps=False, phase=.37 * i)
    for i in range(13):
        t = (i + .5) / 13
        loop = []
        for j in range(stakes * 3):
            angle = tau * j / (stakes * 3)
            interleave = 2.4 * cos(j * pi / 3 + i * pi)
            ripple = .005 * sin(angle * 7 + i)
            loop.append(basket(t + ripple, angle, interleave))
        material = ("reed_light", "reed", "reed", "reed_dark", "reed")[i % 5]
        tube(body, material, loop, [(2.4, 2.05)] * len(loop), sides=6, closed=True, phase=.57 * i)

    tube(body, "frame", [basket(.022, tau * j / 80) for j in range(80)], 4.8, closed=True)
    apron(body, "blue_hide", 0, .77, .38)
    apron(body, "sienna_hide", pi / 2, .52, .30)
    apron(body, "sienna_hide", -pi / 2, .52, .30)
    apron(body, "sienna_hide", pi, .61, .26)
    tube(body, "frame", [basket(1.012, tau * j / 120, 2) for j in range(120)], 5.8, closed=True)

    # Rear badge and its punched fasteners.
    for half_width, height, depth, thread_radius in ((.19, .86, .10, 1.85), (.13, .91, .083, 1.35)):
        badge = [basket(height - depth * (1 - abs(i / 4)), half_width * i / 4, 6.4)
                 for i in range(-4, 5)]
        tube(body, "thread", badge, thread_radius)
    for angle in (-.26, .26):
        ellipsoid(body, "bone", basket(.92, angle, 6.4), (2.9, 2.9, 1.5), segments=8, rings=4)

    for side in (-1, 1):
        # Bent skids and the visible ends of the laminated leaf springs.
        rails = [(43, -28, -147), (57, -44, -126), (65, -50, -88), (68, -55, -32),
                 (68, -53, 40), (65, -49, 93), (58, -39, 128), (43, -27, 145)]
        tube(body, "frame", [(side * x, y, z) for x, y, z in rails], 6.8, sides=12)
        tube(body, "reed", [(side * x, y+6.8, z) for x, y, z in rails], 2.0)
        for wheel in (0 if side < 0 else 1, 3 if side < 0 else 2):
            x, y, z = WHEEL_CENTERS[wheel]
            tube(body, "frame", [(side * 39, -42, z), (side * 67, -40, z), (x, y, z)],
                 [7.5, 6.8, 5.4], sides=10)
            for lamina in range(3):
                drop = lamina * 2.45
                tube(body, "reed_dark" if lamina == 1 else "reed",
                     [(side * 69, -47-drop, z-30), (side * 75, -40-drop, z-15),
                      (side * 81, -33-drop, z), (side * 75, -40-drop, z+15),
                      (side * 69, -47-drop, z+30)], [(1.7, 4.8)] * 5, sides=8)
            lashing(body, (side * 67, -43, z), (1, 0, 0), 8, 11, 4)
        lashing(body, (side * 60, 15, 80), (side * .27, 1, 0), 9, 18, 5)

    # Bentwood hoop behind the driver's head, with a second stave and leather wraps.
    hoop = []
    for i in range(41):
        angle = pi * i / 40
        hoop.append((64 * cos(angle), 8 + 125 * sin(angle), 83 - 3 * sin(angle)))
    tube(body, "frame", hoop, [(7.3, 6.0)] * len(hoop), sides=12)
    tube(body, "reed", [(x * .965, y - 3, z + 6.0) for x, y, z in hoop], 2.2)
    for side in (-1, 1):
        for k in range(2):
            lashing(body, (side * (59 - k * 3), 49 + k * 8, 82),
                    (-side * .25, 1, 0), 7.4, 7, 3, "blue_hide")
        tube(body, "frame", [(side * 61, 18, 110), (side * 56, 47, 88), (side * 54, 57, 81)],
             [5.5, 4.5, 3.5])
        lashing(body, (side * 54, 57, 81), (-side * .25, 1, 0), 8.4, 8, 3)

    tube(body, "frame", [(0, -28, -70), (0, 29, -43), (0, GRIP_Y, GRIP_Z)], [6.5, 5, 4.7])
    tube(body, "frame", [(-39, GRIP_Y, GRIP_Z), (-17, GRIP_Y-1, GRIP_Z),
                         (17, GRIP_Y-1, GRIP_Z), (39, GRIP_Y, GRIP_Z)], 4.1, sides=10)
    for side in (-1, 1):
        lashing(body, (side * 27, GRIP_Y, GRIP_Z), (1, 0, 0), 4.0, 12, 4, "saddle")
        tube(body, "bone", [(side * 51, -12, -125), (side * 36, -7, -143),
                            (side * 22, -1, -151), (side * 17, 8, -150)],
             [6.5, 5.3, 3.5, 1.2], sides=9)
        lashing(body, (side * 43, -9, -133), (-side, .25, -.65), 6.5, 9, 3)
    return body


def make_wheel(index):
    wheel = Mesh()
    front = index < 2
    radius = 57.5 if front else 60.5
    half = 22 if front else 25
    profile = [(-half+4, .61), (-half, .70), (-half-1, .82), (-half+.5, .904),
               (-half+4, .965), (-half+9, .993), (0, 1)]
    profile += [(-x, r) for x, r in reversed(profile[:-1])]
    wheel_ring(wheel, "tire", [(x, r * radius) for x, r in profile], repeat=(4, 1))

    # Two rows of skived hide tread lugs, angled outwards from the crown.
    for i in range(20):
        for side in (-1, 1):
            a = tau * i / 20 + (.038 if side == 1 else -.038)
            path = []
            for j in range(5):
                t = j / 4
                x = side * (2.5 + t * (half - 5.5))
                angle = a + .18 * t
                r = radius * (1 - .052 * t**3) + .8
                path.append((x, r * cos(angle), r * sin(angle)))
            tube(wheel, "tread", path, [(1.6, 2.8), (1.65, 4.2), (1.65, 4.5), (1.55, 4), (1.2, 3)],
                 sides=6, phase=.082 * i, up_hint=(0, cos(a), sin(a)))

    for side in (-1, 1):
        x = side * (half + .62)
        for i in range(28):
            angle = tau * i / 28
            path = []
            for t in (0, .5, 1):
                r = radius * (.756 + .069 * t)
                a = angle + .048 * t
                path.append((x + side * .85 * sin(pi * t), r * cos(a), r * sin(a)))
            tube(wheel, "hide_stitch", path, .73, sides=5, caps=False)

    wheel_ring(wheel, "frame", [(-half+2, radius*.59), (-half+5, radius*.642),
                                (half-5, radius*.642), (half-2, radius*.59),
                                (half-5, radius*.518), (-half+5, radius*.518),
                                (-half+2, radius*.59)], segments=36, repeat=(1, 2))
    for i in range(8):
        angle = tau * i / 8 + (.11 if index in (0, 2) else -.11)
        path = [(0, r * cos(angle), r * sin(angle)) for r in (11, radius*.37, radius*.58)]
        tube(wheel, "reed", path, [5.0, 4.9, 3.8], sides=8, phase=i * .47)
    wheel_ring(wheel, "frame",
               [(-half-5, 7), (-half-3, 15), (-half+1, 18), (-half+7, 14),
                (half-7, 14), (half-1, 18), (half+3, 15), (half+5, 7)], segments=24)
    tube(wheel, "reed_light", [(-half-6.5, 0, 0), (half+6.5, 0, 0)], [7.8, 7.8], sides=10)
    for side in (-1, 1):
        x = side * (half + 4.9)
        lashing(wheel, (x, 0, 0), (1, 0, 0), 7.7, 3.7, 2)
        ellipsoid(wheel, "bone", (x + side * 3, 0, 0), (2.7, 3.7, 3.7), segments=10, rings=4)
    return wheel


def make_vehicle():
    body = make_body()
    wheels = [make_wheel(i) for i in range(4)]
    preview = Mesh()
    preview.extend(body)
    for wheel, center in zip(wheels, WHEEL_CENTERS):
        preview.extend(wheel, center)
    return [body, *wheels, preview]
