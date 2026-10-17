#!/usr/bin/env python3
"""Strip low-opacity gray scanline contamination from generated WebP atlases.

The original art atlases accidentally include broad low-opacity horizontal
bars in the transparent margins. Those bars are not building artwork.
This deterministic, idempotent build preparation keeps authored buildings
but erases background contamination before Godot imports the textures.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "iso07"

def fix(path: Path) -> int:
    with Image.open(path) as original:
        image = original.convert("RGBA")
    old = list(image.getdata())
    cleaned = []
    removed = 0
    for r, g, b, a in old:
        saturation = max(r, g, b) - min(r, g, b)
        # Horizontal bands are translucent desaturated gray pixels,
        # unlike the fully opaque parts of the buildings.
        artifact = a > 0 and (
            a <= 18
            or (a <= 170 and saturation <= 25 and max(r, g, b) <= 185)
        )
        if artifact:
            cleaned.append((0, 0, 0, 0))
            removed += 1
        else:
            cleaned.append((r, g, b, a))
    image.putdata(cleaned)
    # lossless preservation avoids recompression seams on already-cut sprites.
    image.save(path, "WEBP", lossless=True, method=5)
    return removed

def main():
    for path in sorted(ROOT.glob("buildings_*.webp")):
        print(f"CLEAN ATLAS: {path.name}, removed {fix(path)} contaminated pixels")

if __name__ == "__main__":
    main()
