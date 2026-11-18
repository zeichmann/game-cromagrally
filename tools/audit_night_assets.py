"""Audit image metadata using Pillow; --write explicitly regenerates the manifest.

Image pixels are only read and are never modified or resampled.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "meadow_albedo_v2": "exec-a20d1113-8b10-4b05-9c97-608fc0392a82.png",
    "cliff_albedo_v2": "exec-77a3815a-cd8a-47f7-9f5c-98108097959c.png",
    "leaf_canopy_albedo_v2": "exec-e099da38-a587-4d12-a669-48aaa96856c3.png",
    "blossom_canopy_albedo_v2": "exec-ba1d5492-9f4a-4f78-97a4-8c8882ce70f9.png",
    "storybook_sky_panorama_v2": "exec-6f5a2e9a-11b6-4f0f-b47f-eb19e3792e6c.png",
    "shore_albedo_v2": "exec-17573fbe-61a0-41bb-9ddf-a138c16508d6.png",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate the manifest after reviewing asset changes")
    args = parser.parse_args()
    prompts = json.loads((ROOT / "docs/fairytale-assets/NIGHT_PROMPTS.json").read_text(encoding="utf-8-sig"))
    assets = []
    for entry in prompts["assets"]:
        path = ROOT / "assets/textures" / (entry["name"] + ".png")
        with Image.open(path) as img:
            size = img.size
            mode = img.mode
            extrema = list(img.getchannel("A").getextrema()) if "A" in img.getbands() else None
        imported = path.with_suffix(".png.import").read_text(encoding="utf-8")
        assert "mipmaps/generate=true" in imported, path
        assets.append({
            "path": path.relative_to(ROOT).as_posix(),
            "width": size[0], "height": size[1], "mode": mode,
            "alpha_extrema": extrema,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "source": "built-in image_gen", "mode_of_generation": "text-only",
            "reference_images": [], "copied_from_generated_image": SOURCES[entry["name"]],
            "upscaled": False, "mipmaps": True,
            "prompt_file": "docs/fairytale-assets/NIGHT_PROMPTS.json",
        })
    result = {"created": "2026-11-16", "assets": assets}
    manifest = ROOT / "docs/fairytale-assets/NIGHT_ASSET_MANIFEST.json"
    if args.write:
        manifest.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    else:
        assert json.loads(manifest.read_text(encoding="utf-8-sig")) == result, "Asset metadata differs from the reviewed manifest"
    print("NIGHT_ASSET_AUDIT", len(assets), "original images; dimensions, hashes and mipmaps verified")


if __name__ == "__main__":
    main()
