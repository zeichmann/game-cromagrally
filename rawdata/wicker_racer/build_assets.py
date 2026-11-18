"""Build the Wicker Racer BG3D models and AppleDouble skeleton resource."""

from collections import defaultdict
from pathlib import Path
from struct import pack, unpack

from driver import BONES, make_animations, make_driver
from materials import texture
from mesh import sub
from vehicle import make_vehicle


def write_bg3d(path, meshes):
    materials = list(dict.fromkeys(name for mesh in meshes for name in mesh.parts))
    material_ids = {name: i for i, name in enumerate(materials)}
    with path.open("wb") as file:
        file.write(b"BG3D 1.0        \x01\0\0\0")
        for name in materials:
            size, pixels = texture(name)
            file.write(pack(">III4f", 0, 1, 1, 1, 1, 1, 1))  # textured material and white diffuse
            file.write(pack(">IIIiiI16x", 2, size, size, 0x1907, 0x1907, len(pixels)))
            file.write(pixels)
        for mesh in meshes:
            file.write(pack(">I", 3))  # group start
            for name, (vertices, triangles) in mesh.parts.items():
                file.write(pack(">IIi7I16x", 5, 0, 1, material_ids[name], 0, 0, 0, 0, len(vertices), len(triangles)))
                for tag, attr, fmt in ((6, "position", ">3f"), (7, "normal", ">3f"), (8, "uv", ">2f")):
                    file.write(pack(">I", tag))
                    file.write(b"".join(pack(fmt, *getattr(vertex, attr)) for vertex in vertices))
                file.write(pack(">I", 10))
                file.write(b"".join(pack(">3I", *triangle) for triangle in triangles))
            file.write(pack(">I", 4))  # group end
        file.write(pack(">I", 11))  # EOF


def add_unique(values, value, tolerance):
    # The native loader merges matching triples in first-seen order (Bones.c).
    x, y, z = unpack(">3f", pack(">3f", *value))
    for i, (px, py, pz) in enumerate(values):
        if abs(x-px) < tolerance and abs(y-py) < tolerance and abs(z-pz) < tolerance:
            return i
    values.append((x, y, z))
    return len(values) - 1


def skeleton_resources(driver):
    points, normals = [], []
    point_bones = {}
    point_refs = defaultdict(int)
    bone_points = [set() for _ in BONES]
    bone_normals = [set() for _ in BONES]
    for vertices, _ in driver.parts.values():
        for vertex in vertices:
            point = add_unique(points, vertex.position, .001)
            normal = add_unique(normals, vertex.normal, .02)
            bone = vertex.bone
            if point_bones.setdefault(point, bone) != bone:
                raise ValueError(f"Duplicate point {vertex.position} attached to two joints")
            point_refs[point] += 1
            bone_points[bone].add(point)
            bone_normals[bone].add(normal)

    print(f"Driver: {len(points)} points, {len(normals)} normals, {len(driver.parts)} materials")
    if len(points) > 1536 or len(normals) > 1024 or max(point_refs.values()) > 10 or len(driver.parts) > 10:
        raise ValueError("Driver mesh exceeds the native skeleton limits in structs.h")

    animations = make_animations()
    resources = {
        b"Hedr": [(1000, pack(">4h", 0x110, len(animations), len(BONES), len(driver.parts)))],
        b"RelP": [(1000, b"".join(pack(">3f", *sub(p, BONES[point_bones[i]][2])) for i, p in enumerate(points)))],
        b"Bone": [], b"BonP": [], b"BonN": [],
        b"AnHd": [], b"Evnt": [], b"NumK": [], b"KeyF": [],
    }
    for i, (name, parent, pivot) in enumerate(BONES):
        p, n = sorted(bone_points[i]), sorted(bone_normals[i])
        resources[b"Bone"].append((1000+i, pack(">i32s3fHH32x", parent, name.encode(), *pivot, len(p), len(n))))
        resources[b"BonP"].append((1000+i, pack(f">{len(p)}H", *p)))
        resources[b"BonN"].append((1000+i, pack(f">{len(n)}H", *n)))

    for i, (name, frames, events) in enumerate(animations):
        resources[b"AnHd"].append((1000+i, pack(">B32sxh", len(name), name.encode(), len(events))))
        resources[b"Evnt"].append((1000+i, b"".join(pack(">hBB", *event) for event in events)))
        resources[b"NumK"].append((1000+i, bytes([len(frames)] * len(BONES))))
        for joint, (_, parent, pivot) in enumerate(BONES):
            offset = sub(pivot, BONES[parent][2]) if parent >= 0 else pivot
            keys = [pack(">ii9f", time, 1, *offset, *rotations[joint], 1, 1, 1) for time, rotations in frames]
            resources[b"KeyF"].append((1000+i*100+joint, b"".join(keys)))
    return resources


def write_resource_fork(path, resources):
    data = bytearray()
    refs = bytearray()
    types = bytearray(pack(">H", len(resources) - 1))
    ref_base = 2 + 8 * len(resources)
    for kind, entries in resources.items():
        types.extend(pack(">4sHH", kind, len(entries)-1, ref_base + len(refs)))
        for identifier, contents in entries:
            refs.extend(pack(">hHI4x", identifier, 0xFFFF, len(data)))
            data.extend(pack(">I", len(contents)) + contents)
    map_size = 28 + len(types) + len(refs)
    header = pack(">4I", 256, 256 + len(data), len(data), map_size)
    resource_map = header + pack(">8xHH", 28, map_size) + types + refs
    resource_fork = header + bytes(240) + data + resource_map
    apple_double = pack(">II16xHIII", 0x51607, 0x20000, 1, 2, 38, len(resource_fork))
    path.write_bytes(apple_double + resource_fork)


def main():
    data = Path(__file__).resolve().parents[2] / "Data"
    driver = make_driver()
    resources = skeleton_resources(driver)
    write_bg3d(data / "Models" / "WickerRacer.bg3d", make_vehicle(driver))
    write_bg3d(data / "Skeletons" / "WickerDriver.bg3d", [driver])
    write_resource_fork(data / "Skeletons" / "WickerDriver.skeleton.rsrc", resources)


if __name__ == "__main__":
    main()
