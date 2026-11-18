"""Build the Wicker Racer BG3D model."""

from pathlib import Path
from struct import pack

from materials import texture
from vehicle import make_vehicle


def write_bg3d(path, meshes, material_texture=texture):
    materials = list(dict.fromkeys(name for mesh in meshes for name in mesh.parts))
    material_ids = {name: i for i, name in enumerate(materials)}
    with path.open("wb") as file:
        file.write(b"BG3D 1.0        \x01\0\0\0")
        for name in materials:
            size, pixels = material_texture(name)
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


if __name__ == "__main__":
    models = Path(__file__).resolve().parents[2] / "Data" / "Models"
    write_bg3d(models / "WickerRacer.bg3d", make_vehicle())
