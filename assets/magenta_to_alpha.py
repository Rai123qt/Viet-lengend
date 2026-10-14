#!/usr/bin/env python3
"""Flood-fill magenta background -> transparent PNG with defringe.

Usage: python3 magenta_to_alpha.py <input> <output> [--thresh N]
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

def magenta_to_alpha(src, dst, thresh=40, fringe_thresh=110, choke=1):
    img = Image.open(src).convert("RGB")
    w, h = img.size
    # flood fill from all four corners to catch magenta bg
    mask = Image.new("L", (w, h), 0)
    ImageDraw.floodfill(mask, (0, 0), 255, thresh=thresh)
    ImageDraw.floodfill(mask, (w - 1, 0), 255, thresh=thresh)
    ImageDraw.floodfill(mask, (0, h - 1), 255, thresh=thresh)
    ImageDraw.floodfill(mask, (w - 1, h - 1), 255, thresh=thresh)
    # slight grow of the hole into the subject to kill fringe, then feather back
    if choke:
        mask = mask.filter(ImageFilter.MaxFilter(3))  # expand bg region
    alpha = ImageChops.invert(mask)

    # defringe: replace near-magenta pixels (fringe) with neighbour average
    px = img.load()
    apx = alpha.load()
    magenta = (255, 0, 255)
    for y in range(h):
        for x in range(w):
            if apx[x, y] == 0:
                continue
            r, g, b = px[x, y]
            if abs(r - 255) < fringe_thresh and g < fringe_thresh and abs(b - 255) < fringe_thresh:
                # average non-magenta opaque neighbours
                sr = sg = sb = n = 0
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            nr, ng, nb = px[nx, ny]
                            if apx[nx, ny] > 0 and not (abs(nr - 255) < fringe_thresh and ng < fringe_thresh and abs(nb - 255) < fringe_thresh):
                                sr += nr; sg += ng; sb += nb; n += 1
                if n:
                    px[x, y] = (sr // n, sg // n, sb // n)

    out = img.convert("RGBA")
    out.putalpha(alpha)
    out.save(dst)
    # report leftover magenta ratio
    return dst

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    thresh = int(sys.argv[3]) if len(sys.argv) > 3 else 40
    print(magenta_to_alpha(src, dst, thresh))
