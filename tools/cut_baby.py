#!/usr/bin/env python3
"""Cut Baby's character sheet into the sprite the game draws.

Baby is the one character in this game who is not drawn procedurally. She is a
supplied illustration and the brief was to use it exactly, so the pipeline is a
cut-out rather than a redraw:

  1. take the left-hand (front-facing) figure off the two-pose sheet,
  2. lift her off the blurred background with GrabCut, keeping the largest
     connected component so stray background blobs do not survive,
  3. trim to the figure, scale to a height the roster card can use,
  4. split her at the skirt hem into an upper body and two legs, pack those
     into one RGBA atlas, and print the rects and pivots.

The split is what makes her animate rather than slide: `BabySprite.gd` swings
each leg about its hip pivot and squashes the upper body about the waist. The
legs are taken as connected components below the hem - a plain vertical cut
fails, because at the ankles the near shoe crosses in front of the far one and
a rectangular slice of one leg would contain part of the other. Each leg also
keeps a strip of pixels from above the hem so its top tucks under the skirt
instead of showing a cut edge.

If this is re-run against a new sheet, paste the numbers it prints into
BabySprite.gd.

    python3 tools/cut_baby.py <source-sheet.png>
"""

import sys
import numpy as np
import cv2
from PIL import Image

# The sheet is two poses side by side; the front-facing one is on the left.
PANEL_X1 = 515
# Height of the finished sprite. The roster card draws her head at about 200px,
# so anything past this is texture memory nobody sees.
ATLAS_H = 768
OUT = "assets/sprites/baby.png"


# Rows of leg kept above the hem, so the top of a swinging leg stays tucked
# under the skirt.
TUCK = 16


def _largest_components(mask: np.ndarray, want: int) -> list:
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    order = sorted(range(1, count), key=lambda i: -stats[i, cv2.CC_STAT_AREA])
    return [(labels == i).astype(np.uint8) * 255 for i in order[:want]]


def _two_legs(alpha: np.ndarray, y: int) -> bool:
    """Is row `y` two runs that both look like a leg?

    "Two runs" alone is not enough and picks the wrong row every time: the gap
    between a hanging arm and the body splits the silhouette a hundred rows
    above the skirt hem. The arm run is a fraction of the width of the run
    beside it, so require both runs to be substantial and within twice each
    other's width.
    """
    w = alpha.shape[1]
    row = alpha[y].astype(int)
    edges = np.diff(np.concatenate(([0], row, [0])))
    starts = np.where(edges == 1)[0]
    ends = np.where(edges == -1)[0]
    runs = [int(b - a) for a, b in zip(starts, ends) if b - a > w * 0.06]
    if len(runs) != 2:
        return False
    lo, hi = min(runs), max(runs)
    return lo > w * 0.18 and hi < lo * 2.0


def _hem_row(alpha: np.ndarray) -> int:
    """The row the skirt ends on: the first of a run of rows that are all two
    leg-shaped shapes. One row on its own can be a gap between fingers."""
    h = alpha.shape[0]
    for y in range(int(h * 0.45), int(h * 0.80)):
        if all(_two_legs(alpha, k) for k in range(y, min(h, y + 12))):
            return y
    return int(h * 0.58)


def cut(src: str) -> None:
    sheet = cv2.imread(src, cv2.IMREAD_COLOR)
    if sheet is None:
        raise SystemExit(f"cannot read {src}")
    panel = sheet[:, :PANEL_X1].copy()

    mask = np.zeros(panel.shape[:2], np.uint8)
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    # The rect is deliberately generous: GrabCut only needs to be told that the
    # frame edge is background.
    cv2.grabCut(panel, mask, (8, 20, 498, 1500), bgd, fgd, 6, cv2.GC_INIT_WITH_RECT)
    keep = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    keep = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    keep = cv2.morphologyEx(keep, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    parts = _largest_components(keep, 1)
    if parts:
        keep = parts[0]
    # A one-pixel feather stops the cut-out reading as a sticker at small sizes.
    keep = cv2.GaussianBlur(keep, (5, 5), 0)

    rgba = np.dstack([cv2.cvtColor(panel, cv2.COLOR_BGR2RGB), keep])
    ys, xs = np.where(keep > 40)
    figure = Image.fromarray(rgba[int(ys.min()):int(ys.max()) + 1,
                                  int(xs.min()):int(xs.max()) + 1])
    scale = ATLAS_H / figure.height
    figure = figure.resize((max(1, round(figure.width * scale)), ATLAS_H), Image.LANCZOS)
    arr = np.array(figure)
    alpha = arr[..., 3] > 60

    hem = _hem_row(alpha)
    legs_mask = np.zeros(alpha.shape, np.uint8)
    legs_mask[hem:] = (alpha[hem:] * 255).astype(np.uint8)
    legs = _largest_components(legs_mask, 2)
    if len(legs) < 2:
        raise SystemExit(f"could not separate the legs at row {hem}")
    # Left-hand leg first, so the rects come out in a predictable order.
    legs.sort(key=lambda m: float(np.where(m > 0)[1].mean()))

    # Tuck: hand the rows just above the hem to whichever leg is nearer.
    centres = [float(np.where(m[hem:hem + 8] > 0)[1].mean()) for m in legs]
    for y in range(max(0, hem - TUCK), hem):
        for x in np.where(alpha[y])[0]:
            near = 0 if abs(x - centres[0]) <= abs(x - centres[1]) else 1
            legs[near][y, x] = 255

    pieces = []
    upper = np.zeros(alpha.shape, np.uint8)
    upper[:hem + 2] = 255
    pieces.append(("UPPER", upper))
    pieces.append(("LEG_L", legs[0]))
    pieces.append(("LEG_R", legs[1]))

    # Pack: upper on top, the two legs side by side under it.
    crops = []
    for name, m in pieces:
        cut_rgba = arr.copy()
        cut_rgba[..., 3] = np.minimum(cut_rgba[..., 3], m)
        yy, xx = np.where(cut_rgba[..., 3] > 8)
        box = (int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1)
        crops.append((name, Image.fromarray(cut_rgba).crop(box), box))

    up_w, up_h = crops[0][1].size
    leg_w = crops[1][1].width + crops[2][1].width
    leg_h = max(crops[1][1].height, crops[2][1].height)
    atlas = Image.new("RGBA", (max(up_w, leg_w), up_h + leg_h), (0, 0, 0, 0))
    at = {}
    atlas.paste(crops[0][1], (0, 0))
    at["UPPER"] = (0, 0, up_w, up_h, crops[0][2])
    atlas.paste(crops[1][1], (0, up_h))
    at["LEG_L"] = (0, up_h, crops[1][1].width, crops[1][1].height, crops[1][2])
    atlas.paste(crops[2][1], (crops[1][1].width, up_h))
    at["LEG_R"] = (crops[1][1].width, up_h, crops[2][1].width, crops[2][1].height, crops[2][2])
    atlas.save(OUT)

    print(f"atlas    {atlas.width}x{atlas.height} -> {OUT}")
    print(f"figure   {figure.width}x{figure.height}   hem row {hem}")
    print("# rect_in_atlas(x, y, w, h)   offset_in_figure(x, y)")
    for name in ("UPPER", "LEG_L", "LEG_R"):
        x, y, w, h, box = at[name]
        print(f"{name:6s} RECT({x}, {y}, {w}, {h})   ORIGIN({box[0]}, {box[1]})")



if __name__ == "__main__":
    cut(sys.argv[1] if len(sys.argv) > 1 else "baby_sheet.png")
