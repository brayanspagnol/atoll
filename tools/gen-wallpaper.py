#!/usr/bin/env python3
"""Generates the default wallpaper: layered islands in dusk haze. Output is deterministic.

Usage: gen-wallpaper.py OUTPUT [WIDTH HEIGHT]. Requires numpy and Pillow.
"""
import sys

import numpy as np
from PIL import Image


def ridge(width, rng, base, amplitude, roughness=0.55, octaves=7):
    """A 1D fractal profile: sum of random-phase sines at doubling frequencies."""
    x = np.linspace(0, 1, width)
    y = np.zeros(width)
    gain = 1.0
    frequency = rng.uniform(1.5, 3.0)
    for _ in range(octaves):
        y += gain * np.sin(2 * np.pi * (frequency * x + rng.uniform(0, 1)))
        gain *= roughness
        frequency *= 2.03
    return base + amplitude * y


def main():
    out = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 3440
    height = int(sys.argv[3]) if len(sys.argv) > 3 else 1440
    rng = np.random.default_rng(1404)

    yy, xx = np.mgrid[0:height, 0:width]
    v = yy / height

    # Sky: deep navy at the top down to a pale horizon.
    stops = np.array([0.0, 0.34, 0.56, 0.72])
    colors = np.array([[16, 28, 48], [44, 76, 112], [120, 156, 182], [226, 214, 202]], dtype=float)
    image = np.stack([np.interp(v, stops, colors[:, i]) for i in range(3)], axis=-1)

    # Low sun behind the haze.
    sx, sy = 0.62 * width, 0.56 * height
    distance = np.hypot((xx - sx) / height, (yy - sy) / height)
    glow = np.exp(-(distance / 0.34) ** 2)[..., None]
    image = image * (1 - 0.55 * glow) + np.array([255, 226, 196]) * 0.55 * glow

    # Islands, far to near: each layer darker and sharper, with haze rising from its base.
    layers = [
        (0.60, 0.028, [108, 142, 170]),
        (0.66, 0.040, [76, 112, 144]),
        (0.73, 0.052, [48, 82, 114]),
        (0.81, 0.060, [28, 54, 82]),
        (0.91, 0.052, [12, 26, 44]),
    ]
    for base, amplitude, color in layers:
        top = ridge(width, rng, base * height, amplitude * height)
        depth = np.clip((yy - top) / (0.16 * height), 0, 1)[..., None]
        fill = np.array(color, dtype=float) + depth * 26
        mask = np.clip(yy - top + 0.5, 0, 1)[..., None]
        image = image * (1 - mask) + fill * mask

    # Fine grain prevents banding in the long gradients.
    image += rng.normal(0, 1.2, image.shape)
    Image.fromarray(np.clip(image, 0, 255).astype(np.uint8)).save(out, quality=90, optimize=True)


if __name__ == "__main__":
    main()
