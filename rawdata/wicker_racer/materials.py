"""Small, tileable source textures for the original car and driver meshes."""

from functools import cache
from math import cos, floor, sin, tau
from random import Random


PALETTES = {
    "basket_lining": ((95, 62, 39), "weave"),
    "reed": ((184, 128, 68), "wood"),
    "reed_dark": ((151, 96, 48), "wood"),
    "reed_light": ((219, 163, 98), "wood"),
    "frame": ((122, 73, 46), "wood"),
    "cord": ((170, 127, 79), "twist"),
    "thread": ((218, 177, 113), "twist"),
    "bone": ((204, 175, 129), "grain"),
    "blue_hide": ((52, 95, 101), "paint"),
    "sienna_hide": ((162, 86, 46), "paint"),
    "saddle": ((92, 56, 37), "leather"),
    "tire": ((62, 49, 44), "leather"),
    "tread": ((80, 65, 56), "leather"),
    "hide_stitch": ((120, 94, 73), "twist"),
}


class Noise:
    def __init__(self, random, size):
        self.size = size
        self.points = [[random.uniform(-1, 1) for _ in range(size)] for _ in range(size)]

    def __call__(self, u, v):
        x, y = floor(u * self.size), floor(v * self.size)
        s, t = u * self.size - x, v * self.size - y
        s = s*s*(3 - 2*s)
        t = t*t*(3 - 2*t)
        top, bottom = self.points[y % self.size], self.points[(y+1) % self.size]
        i, j = x % self.size, (x+1) % self.size
        return (top[i] * (1-s) + top[j] * s) * (1-t) + (bottom[i] * (1-s) + bottom[j] * s) * t


def pattern(u, v, soft, detail, fleck, motif):
    if motif == "wood":
        return (14 * soft + 7 * detail
                + 8 * sin(tau * (6*v + .4*soft))
                + 5 * sin(tau * (27*v + .67*soft + .12*detail)) + 3 * fleck)
    if motif == "weave":
        band = (cos(tau * (38*u + .1*detail)) + cos(tau * (20*v + .09*soft))) / 2
        return 9 * soft + 14 * band + 6 * detail + 4 * fleck
    if motif == "twist":
        return 11 * sin(tau * (9*u + v)) + 4 * sin(tau * (18*u + 2*v)) + 7 * soft + 6 * fleck
    if motif == "paint":
        edge = abs(v - .5 + .06 * sin(tau*u))
        border = 15 * max(0, 1 - 25 * abs(edge - .32))
        return 16 * soft + 9 * detail + 8 * fleck + border
    if motif == "leather":
        pebble = 10 * abs(detail) - 10 * max(0, .3 - abs(fleck))
        return 12 * soft + pebble + 7 * fleck
    return 6 * soft + 4 * detail + 4 * fleck


@cache
def texture(name):
    color, motif = PALETTES[name]
    size = 256 if motif in {"wood", "leather", "paint"} else 128
    random = Random(name)
    large, small = Noise(random, 8), Noise(random, 32)
    pixels = bytearray()
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            soft, detail, fleck = large(u, v), small(u, v), random.uniform(-1, 1)
            brightness = pattern(u, v, soft, detail, fleck, motif)
            faded = 14 * max(0, (detail + fleck) * .55 - .57) if motif == "paint" else 0
            for channel, oxidation in zip(color, (2, .7, -.24)):
                pixels.append(round(max(0, min(255, channel + brightness + faded * oxidation))))
    return size, pixels
