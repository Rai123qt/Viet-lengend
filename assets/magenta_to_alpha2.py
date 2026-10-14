#!/usr/bin/env python3
"""Robust magenta -> transparent: chroma key + erode + soft edge + trim + downscale.
Usage: python3 magenta_to_alpha2.py <src> <dst> [max_side]
"""
import sys
import numpy as np
from PIL import Image, ImageFilter


def convert(src, dst, max_side=1024, tol=70, erode=2):
    img = Image.open(src).convert("RGBA")
    a = np.array(img)
    rgb = a[..., :3].astype(np.int16)
    # near-magenta test
    m = (np.abs(rgb[..., 0] - 255) < tol) & (rgb[..., 1] < tol) & (np.abs(rgb[..., 2] - 255) < tol)
    alpha = np.where(m, 0, 255).astype(np.uint8)
    # erode opaque region to kill fringe: MinFilter on alpha shrinks white areas
    am = Image.fromarray(alpha, "L")
    for _ in range(erode):
        am = am.filter(ImageFilter.MinFilter(3))
    am = am.filter(ImageFilter.GaussianBlur(0.8))
    a[..., 3] = np.array(am)
    out = Image.fromarray(a, "RGBA")
    # trim fully-transparent borders
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    # downscale
    w, h = out.size
    if max(w, h) > max_side:
        r = max_side / max(w, h)
        out = out.resize((int(w * r), int(h * r)), Image.LANCZOS)
    out.save(dst, optimize=True)
    return dst


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    ms = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
    print(convert(src, dst, ms))
