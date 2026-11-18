"""Mesh construction in the game's X-right, Y-up, Z-back coordinates."""

from collections import defaultdict
from dataclasses import dataclass, replace
from math import cos, dist, pi, sin, sqrt, tau


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(v, factor):
    return tuple(x * factor for x in v)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    x, y, z = a
    u, v, w = b
    return (y * w - z * v, z * u - x * w, x * v - y * u)


def unit(v):
    return mul(v, 1 / sqrt(dot(v, v)))


UP = (0, 1, 0)
FORWARD = (0, 0, -1)


@dataclass(frozen=True)
class Vertex:
    position: tuple
    normal: tuple
    uv: tuple


class Mesh:
    def __init__(self):
        self.parts = defaultdict(lambda: ([], []))

    def grid(self, material, rows, reverse=False):
        """Insert a grid of rows of vertices, sharing collapsed pole vertices."""
        vertices, triangles = self.parts[material]
        indices = {}
        for y, row in enumerate(rows):
            for x, vertex in enumerate(row):
                if x and vertex == row[x-1]:
                    indices[y, x] = indices[y, x-1]
                else:
                    indices[y, x] = len(vertices)
                    vertices.append(vertex)
        for y in range(len(rows) - 1):
            for x in range(len(rows[y]) - 1):
                a, b = indices[y, x], indices[y, x+1]
                c, d = indices[y+1, x], indices[y+1, x+1]
                for triangle in ((a, b, c), (b, d, c)):
                    if len(set(triangle)) == 3:
                        triangles.append(triangle[::-1] if reverse else triangle)

    def extend(self, source, offset=(0, 0, 0)):
        for material, (source_vertices, source_triangles) in source.parts.items():
            vertices, triangles = self.parts[material]
            start = len(vertices)
            vertices.extend(replace(v, position=add(v.position, offset)) for v in source_vertices)
            triangles.extend(tuple(start + i for i in t) for t in source_triangles)


def tube(mesh, material, path, radius, *, sides=8, closed=False, caps=True, phase=0, up_hint=None):
    """Sweep a round or oval section along a polyline with a transported frame."""
    radii = [radius] * len(path) if isinstance(radius, (int, float)) else radius
    tangents = []
    for i in range(len(path)):
        before = path[i-1] if i > 0 or closed else path[i]
        after = path[(i+1) % len(path)] if closed or i+1 < len(path) else path[i]
        tangents.append(unit(sub(after, before)))
    reference = up_hint if up_hint is not None else (UP if abs(dot(tangents[0], UP)) < .86 else FORWARD)
    normal = unit(sub(reference, mul(tangents[0], dot(reference, tangents[0]))))
    rows = []
    length = 0.0
    for i, (point, tangent, section) in enumerate(zip(path, tangents, radii)):
        if i:
            length += dist(path[i-1], point)
        normal = unit(sub(normal, mul(tangent, dot(normal, tangent))))
        axis = cross(tangent, normal)
        r1, r2 = (section, section) if isinstance(section, (int, float)) else section
        u = phase + length / 78
        row = []
        for side in range(sides + 1):
            fraction = side / sides
            angle = tau * (side % sides) / sides
            a, b = cos(angle), sin(angle)
            offset = add(mul(normal, r1 * a), mul(axis, r2 * b))
            surface_normal = unit(add(mul(normal, a / r1), mul(axis, b / r2)))
            row.append(Vertex(add(point, offset), surface_normal, (u, fraction)))
        rows.append(row)

    if closed:
        u = phase + (length + dist(path[-1], path[0])) / 78
        rows.append([replace(v, uv=(u, v.uv[1])) for v in rows[0]])
    elif caps:
        start = Vertex(path[0], mul(tangents[0], -1), (phase, .5))
        end = Vertex(path[-1], tangents[-1], (phase + length / 78, .5))
        rows.insert(0, [start] * (sides + 1))
        rows.append([end] * (sides + 1))
    mesh.grid(material, rows)


def surface(mesh, material, position, columns, rings, *, reverse=False, poles=(), repeat=(1, 1)):
    """Sample a parametric surface with smooth normals and an explicit UV seam."""
    rows = []
    epsilon = .0001
    for j in range(rings + 1):
        v = j / rings
        if j in poles:
            normal = (0, -1, 0) if j == 0 else (0, 1, 0)
            vertex = Vertex(position(.5, v), normal, (.5, v))
            rows.append([vertex] * (columns + 1))
            continue
        row = []
        for i in range(columns + 1):
            u = i / columns
            du = sub(position(u + epsilon, v), position(u - epsilon, v))
            dv = sub(position(u, v + epsilon), position(u, v - epsilon))
            normal = unit(cross(du, dv))
            if reverse:
                normal = mul(normal, -1)
            row.append(Vertex(position(u, v), normal, (repeat[0] * u, repeat[1] * v)))
        rows.append(row)
    mesh.grid(material, rows, reverse)


def ellipsoid(mesh, material, center, radii, *, segments=12, rings=6, angle=0):
    def position(u, v):
        around, latitude = tau * u, pi * (v - .5)
        x = radii[0] * sin(around) * cos(latitude)
        z = radii[2] * cos(around) * cos(latitude)
        return add(center, (x * cos(angle) + z * sin(angle), radii[1] * sin(latitude),
                            z * cos(angle) - x * sin(angle)))

    surface(mesh, material, position, segments, rings, poles=(0, rings))


def sample_profile(profile, t):
    """Interpolate the rows of a profile, with end tangents for surface normals."""
    index = min(len(profile) - 2, max(0, int(t)))
    fraction = t - index
    return add(profile[index], mul(sub(profile[index+1], profile[index]), fraction))


def wheel_ring(mesh, material, profile, segments=48, *, repeat=(1, 1)):
    def position(u, v):
        x, radius = sample_profile(profile, v * (len(profile) - 1))
        return (x, radius * cos(tau * u), radius * sin(tau * u))

    surface(mesh, material, position, segments, len(profile) - 1, repeat=repeat)
