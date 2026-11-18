"""Generate the desert spectators and a softly edged wheel-dust sprite."""

from functools import cache
from math import cos, exp, floor, pi, sin, tau
from pathlib import Path
from random import Random
from struct import pack
import sys
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "wicker_racer"))
from build_assets import write_bg3d
from materials import Noise
from mesh import Mesh, ellipsoid, surface, tube
from vehicle import lashing


COLORS = {
    "feather": (61, 115, 132),
    "wing": (41, 83, 107),
    "crest": (221, 122, 63),
    "neck": (160, 183, 160),
    "beak": (240, 163, 61),
    "foot": (200, 145, 70),
    "eye": (255, 243, 211),
    "pupil": (38, 34, 28),
    "glint": (255, 255, 244),
    "clay": (176, 89, 56),
    "ochre": (231, 155, 85),
    "inside": (92, 54, 38),
    "cactus": (87, 146, 75),
    "rib": (113, 162, 88),
    "spine": (235, 193, 121),
    "flower": (234, 90, 63),
    "stone": (83, 91, 83),
    "pebble": (182, 145, 105),
    "wood": (120, 76, 47),
    "cord": (171, 126, 72),
    "bone": (218, 187, 132),
    "lens": (64, 136, 144),
    "skin": (154, 171, 82),
    "shell": (166, 108, 59),
    "scute": (223, 156, 84),
    "scarf": (58, 126, 128),
    "flag": (255, 231, 165),
    "spark": (255, 221, 139),
}


def clamp(value, high=255):
    return max(0, min(high, round(value)))


@cache
def material_texture(name):
    size = 64
    random = Random("desert-" + name)
    soft, grain = Noise(random, 7), Noise(random, 23)
    base_color = COLORS[name]
    pixels = bytearray()
    for y in range(size):
        v = (y + .5) / size
        for x in range(size):
            u = (x + .5) / size
            rgb = base_color
            detail = 8 * soft(u, v) + 6 * grain(u, v)
            if name in {"feather", "wing", "crest"}:
                detail += 5 * sin(tau * (v * 14 + .28 * soft(u, v)))
            elif name in {"wood", "cord"}:
                detail += 7 * sin(tau * (v * 11 + .4 * soft(u, v)))
            elif name == "clay":
                triangle = 1 - abs(2 * ((14*u) % 1) - 1)
                if .27 < v < .28 + .075*triangle:
                    rgb = (223, 140, 75)
                detail += 4 * sin(tau * (v*16 + .19*soft(u, v)))
            elif name in {"scute", "shell", "stone", "pebble"}:
                detail += 8 * soft(u, v) + 5 * sin(tau * (v*7 + .3*soft(u, v)))
            elif name == "flag":
                if min(u, v, 1-u, 1-v) < .05:
                    rgb = (164, 103, 58)
                elif (floor(u * 6) + floor(v * 4)) % 2:
                    rgb = (105, 56, 48)
            elif name in {"eye", "glint", "pupil"}:
                detail *= .24
            pixels.extend(clamp(channel + detail) for channel in rgb)
    return size, pixels


def horizontal_ring(mesh, material, x, y, z, radius, section):
    path = [(x + radius * cos(tau*i/24), y, z + radius * sin(tau*i/24)) for i in range(24)]
    tube(mesh, material, path, section, sides=6, closed=True, up_hint=(0, 1, 0))


def eyes(mesh, x, y, z, size):
    for side in (-1, 1):
        cx = side*x
        ellipsoid(mesh, "eye", (cx, y, z), (size, 1.16*size, .68*size), segments=16)
        ellipsoid(mesh, "pupil", (cx-side*3, y+1, z-.59*size), (.48*size, .57*size, .22*size), segments=12)
        ellipsoid(mesh, "glint", (cx-side*3-3, y+5, z-.80*size), (3.0, 3.3, 1.9), segments=8, rings=4)


def ostrich():
    body = Mesh()
    for side in (-1, 1):
        x = side*40
        tube(body, "foot", [(x, 131, 20), (x+side*4, 85, 12), (x, 37, 20), (x, 10, 15)],
             [10, 7, 8, 7], sides=9)
        for toe in (-1, 0, 1):
            tube(body, "foot", [(x, 9, 15), (x+12*toe, 5, -13), (x+23*toe, 3, -36)],
                 [5, 4.5, 2], sides=7)
    ellipsoid(body, "feather", (0, 152, 16), (75, 57, 89), segments=22, rings=9)
    ellipsoid(body, "neck", (0, 150, -45), (49, 43, 40), segments=16)
    for side in (-1, 1):
        ellipsoid(body, "wing", (side*57, 153, 22), (26, 37, 63), segments=16)
        for i in range(4):
            tube(body, "feather", [(side*(59+4*i), 153-8*i, 21), (side*(71+3*i), 141-6*i, 70),
                                   (side*(67+2*i), 128-6*i, 96)], [8, 10, 2.5], sides=7)
    for i in range(-2, 3):
        tube(body, "wing", [(i*12, 168, 68), (i*20, 193+3*abs(i), 113), (i*26, 204-4*abs(i), 153)],
             [11, 12, 2], sides=7)

    # Open clay pot. The bird can bend down far enough to hide its beak in it.
    z = -154
    profile = [(0, 44), (8, 52), (27, 64), (51, 70), (67, 65), (74, 61),
               (74, 53), (64, 52), (51, 58), (26, 55), (13, 43)]
    # Use an explicit revolved profile so that the neck of the pot stays open.
    def pot(u, v):
        f = v*(len(profile)-1)
        i = max(0, min(len(profile)-2, floor(f)))
        y, radius = (a + (b-a)*(f-i) for a, b in zip(profile[i], profile[i+1]))
        scale = 1 + .019*sin(5*tau*u) + .014*cos(3*tau*u)
        return (sin(tau*u)*radius*scale, y, z+cos(tau*u)*radius*scale)
    surface(body, "clay", pot, 36, len(profile)-1)
    ellipsoid(body, "inside", (0, 12, z), (42, 3, 42), segments=18, rings=4)
    horizontal_ring(body, "ochre", 0, 73, z, 57, 4.5)
    horizontal_ring(body, "ochre", 0, 37, z, 67, 2.8)

    neck = Mesh()
    tube(neck, "neck", [(0, 0, 0), (0, 33, 2), (0, 79, -2), (0, 119, -11), (0, 146, -24)],
         [25, 20, 15, 16, 19], sides=14)
    head = Mesh()
    ellipsoid(head, "neck", (0, 8, -4), (43, 39, 41), segments=20, rings=8)
    eyes(head, 19, 19, -32, 15.5)
    ellipsoid(head, "beak", (0, -4, -49), (30, 13, 24), segments=16)
    ellipsoid(head, "foot", (0, -12, -50), (25, 6, 22), segments=14)
    for i in (-1, 0, 1):
        tube(head, "crest", [(i*8, 34, 9), (i*14, 49-4*abs(i), 17), (i*20, 55-5*abs(i), 36)],
             [5.5, 4, 1], sides=6)
    return body, neck, head


def cactus_photographer():
    body = Mesh()
    ellipsoid(body, "cactus", (0, 129, 0), (68, 132, 53), segments=20, rings=12)
    for i in range(9):
        angle = tau*i/9
        path = [(cos(angle)*68*cos(t), 128+129*sin(t), sin(angle)*53*cos(t))
                for t in [-1.30,-.97,-.65,-.32,0,.32,.65,.97,1.30]]
        tube(body, "rib", path, [3, 5, 6, 7, 7, 6, 5, 4, 2], sides=6)
        for k in (2, 4, 6):
            x, y, z = path[k]
            tube(body, "spine", [(x, y, z), (x+8*cos(angle), y+10, z+8*sin(angle))], [2.2, .3], sides=5)
    for side in (-1, 1):
        tube(body, "cactus", [(side*48, 75, -2), (side*75, 91, -22), (side*77, 118, -45),
                              (side*51, 129, -72)], [23, 20, 17, 18], sides=12)
        ellipsoid(body, "cactus", (side*47, 126, -72), (21, 17, 18), segments=12)
    eyes(body, 26, 195, -42, 20)
    tube(body, "inside", [(-19, 162, -50), (0, 155, -57), (20, 161, -50)], 3.6, sides=7)
    for i in range(7):
        theta = i*tau/7
        tube(body, "flower", [(9, 248, 0), (9+15*cos(theta), 257, 15*sin(theta)),
                              (9+27*cos(theta), 267, 27*sin(theta))], [5, 8, 2], sides=7)
    ellipsoid(body, "beak", (9, 261, 0), (10, 8, 10), segments=12)
    for x, z, size in [(-35, -21, 18), (25, -24, 23), (39, 18, 16), (-22, 32, 15)]:
        ellipsoid(body, "pebble", (x, 6, z), (size, size*.65, size*.82), segments=10, rings=5)

    camera = Mesh()
    ellipsoid(camera, "stone", (0, 0, 0), (57, 33, 29), segments=16, rings=7)
    tube(camera, "bone", [(0, 0, -22), (0, 0, -39), (0, 0, -42)], [24, 28, 24], sides=20)
    ellipsoid(camera, "lens", (0, 0, -42), (19, 19, 5.5), segments=18, rings=6)
    ellipsoid(camera, "bone", (33, 26, -12), (12, 10, 10), segments=12)
    ellipsoid(camera, "lens", (33, 26, -20), (8, 7, 2), segments=10)
    flash = Mesh()
    ellipsoid(flash, "glint", (0, 0, 0), (17, 14, 4), segments=14)
    for i in range(8):
        angle = i*tau/8
        x, y = cos(angle), sin(angle)
        reach = 44 if i % 2 == 0 else 29
        tube(flash, "glint" if i % 2 == 0 else "spark",
             [(5*x, 5*y, -1), (15*x, 15*y, -2), (reach*x, reach*y, -2)], [5, 3.8, .5], sides=6)
    return body, camera, flash


def turtle_marshal():
    turtle = Mesh()
    for side in (-1, 1):
        for z in (-54, 53):
            ellipsoid(turtle, "skin", (side*62, 16, z), (28, 19, 38), segments=14)
            for i in (-1, 0, 1):
                ellipsoid(turtle, "bone", (side*64+i*11, 8, z-32), (4.8, 5.5, 8), segments=8, rings=4)
    ellipsoid(turtle, "skin", (0, 49, 0), (87, 40, 104), segments=20, rings=7)
    ellipsoid(turtle, "shell", (0, 70, 7), (99, 65, 117), segments=24, rings=10)
    for i in range(8):
        a = tau*i/8
        ellipsoid(turtle, "scute", (59*sin(a), 104, 7+68*cos(a)), (27, 22, 31),
                  segments=13, rings=5, angle=a)
    ellipsoid(turtle, "scute", (0, 122, 7), (38, 18, 48), segments=16)
    horizontal_ring(turtle, "bone", 0, 62, 7, 90, (4.8, 5.6))
    tube(turtle, "skin", [(0, 28, 91), (0, 21, 125), (-12, 14, 148)], [12, 8, 1.5])
    tube(turtle, "skin", [(57, 40, -65), (86, 67, -52), (110, 66, -45)], [20, 15, 13], sides=10)
    ellipsoid(turtle, "scarf", (0, 52, -76), (53, 19, 30), segments=16)

    head = Mesh()
    ellipsoid(head, "skin", (0, 13, -13), (49, 40, 51), segments=18, rings=8)
    ellipsoid(head, "skin", (0, -7, -50), (40, 21, 28), segments=16)
    tube(head, "inside", [(-26, -7, -62), (-13, -13, -75), (18, -13, -74), (29, -5, -63)], 3.2, sides=7)
    eyes(head, 22, 29, -48, 17)
    for x in (-10, 10):
        ellipsoid(head, "inside", (x, 4, -74), (3.2, 3, 1.7), segments=8, rings=4)
    flag = Mesh()
    tube(flag, "wood", [(0, -16, 0), (0, 94, 0), (5, 215, 0)], [6, 5, 4], sides=9)
    ellipsoid(flag, "bone", (5, 218, 0), (9, 10, 9), segments=10)
    lashing(flag, (4, 191, 0), (0, 1, 0), 5, 13, 4)
    lashing(flag, (1.8, 121, 0), (0, 1, 0), 5, 13, 4)

    def cloth(u, v):
        return (6 + (137-16*v)*u, 200-84*v - 18*u + 7*sin(pi*u),
                (3*sin(3*tau*u - v) + 20*sin(2.3*pi*u))*u)

    surface(flag, "flag", cloth, 18, 8)
    surface(flag, "flag", cloth, 18, 8, reverse=True)
    return turtle, head, flag


def dust_png(path):
    size = 128
    random = Random(8825)
    soft, detail = Noise(random, 7), Noise(random, 32)
    lobes = [(-.43, -.19, .44, .37), (.02, -.28, .53, .33), (.39, -.08, .40, .45),
             (-.23, .20, .55, .34), (.13, .23, .44, .41), (.03, .0, .44, .43)]
    data = bytearray()
    for y in range(size):
        data.append(0)  # PNG scanline filter
        v = (y + .5) / size
        for x in range(size):
            u = (x + .5) / size
            noise = soft(u, v)
            fx, fy = 2*u-1 + .10*noise, 2*v-1 + .05*noise
            density = sum(exp(-2.2*(((fx-cx)/rx)**2 + ((fy-cy)/ry)**2)) for cx, cy, rx, ry in lobes)
            edge = max(0, min(1, (1-max(abs(fx), abs(fy))) * 5))
            opacity = min(1, .57*density) * edge**1.5 * (.83 + .16*noise + .11*detail(u, v))
            light = 11*noise + 6*detail(u, v) + 12*(.5-v)
            data.extend((*[clamp(c + light) for c in (181, 132, 86)], clamp(236*opacity)))

    def chunk(name, content):
        return pack(">I", len(content)) + name + content + pack(">I", zlib.crc32(name + content))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", pack(">2I5B", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(data, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


if __name__ == "__main__":
    data = Path(__file__).resolve().parents[2] / "Data"
    models = [*ostrich(), *cactus_photographer(), *turtle_marshal()]
    write_bg3d(data / "Models" / "DesertGags.bg3d", models, material_texture)
    dust_png(data / "Sprites" / "wheeldust.png")
