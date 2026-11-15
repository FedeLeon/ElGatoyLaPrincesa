#!/usr/bin/env python3
"""Prepare generated forest materials for mipmapped Godot use."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
JOBS = {
    ROOT / "assets/created/source/bark_normal_tree_painterly_source.png": ROOT / "assets/created/materials/bark_painterly.png",
    ROOT / "assets/created/source/ridge_stone_painterly_source.png": ROOT / "assets/created/materials/ridge_stone_painterly.png",
    ROOT / "assets/created/source/grass_painterly_source.png": ROOT / "assets/created/materials/grass_painterly.png",
    ROOT / "assets/created/source/ranger_basecolor_source.png": ROOT / "assets/created/materials/princess_ranger_basecolor.png",
}
SIZE = 1024


def main() -> int:
    for source, destination in JOBS.items():
        if not source.is_file():
            print(f"Missing source: {source}", file=sys.stderr)
            return 1
        original = Image.open(source).convert("RGB")
        output_size = 512 if destination.name == "grass_painterly.png" else original.width if destination.name == "princess_ranger_basecolor.png" else SIZE
        image = original if original.size == (output_size, output_size) else original.resize((output_size, output_size), Image.Resampling.LANCZOS)
        if destination.name == "bark_painterly.png":
            # Keep the brush-painted grain without the source's orange cast.
            image = ImageEnhance.Color(image).enhance(0.68)
            image = ImageEnhance.Brightness(image).enhance(0.9)
        elif destination.name == "princess_ranger_basecolor.png":
            # Lift only the dark green cloth pixels, retaining every atlas island
            # and all original skin, leather, metal, UV, and texture detail.
            pixels = np.asarray(image, dtype=np.float32)
            red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
            green_cloth = (green > red * 1.12) & (green > blue * 1.1) & (red < 120) & (green < 170)
            pixels[green_cloth] = 255.0 * np.power(pixels[green_cloth] / 255.0, 0.82)
            image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
        image.save(destination, optimize=True)
        print(f"{destination.relative_to(ROOT)}: {output_size}x{output_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
