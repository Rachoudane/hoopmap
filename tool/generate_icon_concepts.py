"""Generates five distinct icon concepts for Hoopmap, all in the existing
brand palette, no logos or existing marks. Each is a flat, single-silhouette
pictogram (no gradients, no text) so it stays legible small and in
grayscale.

Writes 1024x1024 PNGs to design/icons/, plus a 48x48 color and 48x48
grayscale preview of each for legibility review, and a single contact
sheet (icon_concepts_contact_sheet.png) for a side-by-side look.

Run from the repo root:
    python tool/generate_icon_concepts.py
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "design" / "icons"

ASPHALT = (20, 23, 27, 255)
CHALK = (246, 243, 238, 255)
ORANGE = (242, 102, 26, 255)
ORANGE_LIGHT = (255, 138, 71, 255)
TEAL = (31, 166, 160, 255)
SEAM_DARK = (28, 20, 12, 255)

SIZE = 1024
SS = 4  # supersample factor for anti-aliasing


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    hi = SIZE * SS
    img = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img), hi


def _finish(img: Image.Image) -> Image.Image:
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def concept_front_hoop() -> Image.Image:
    """1. A basketball hoop seen from the front: backboard, rim, net."""
    img, draw, hi = _canvas()
    cx = hi // 2

    board_w, board_h = round(hi * 0.6), round(hi * 0.38)
    board_top = round(hi * 0.16)
    board_box = (
        cx - board_w // 2,
        board_top,
        cx + board_w // 2,
        board_top + board_h,
    )
    draw.rounded_rectangle(board_box, radius=round(hi * 0.04), fill=CHALK)

    rim_y = board_top + round(board_h * 0.82)
    rim_w, rim_h = round(hi * 0.5), round(hi * 0.12)
    rim_box = (cx - rim_w // 2, rim_y - rim_h // 2, cx + rim_w // 2, rim_y + rim_h // 2)
    draw.ellipse(rim_box, outline=ORANGE, width=round(hi * 0.045))

    # Net: converging lines from the rim's underside to a point below.
    net_bottom_y = rim_y + round(hi * 0.34)
    stroke = max(2, round(hi * 0.012))
    net_points = 7
    for i in range(net_points):
        t = i / (net_points - 1)
        start_x = rim_box[0] + t * rim_w
        end_x = cx + (start_x - cx) * 0.18
        draw.line(
            (start_x, rim_y, end_x, net_bottom_y),
            fill=SEAM_DARK,
            width=stroke,
        )
    # Two horizontal net cross-lines for a woven look.
    for frac in (0.4, 0.72):
        y = rim_y + frac * (net_bottom_y - rim_y)
        span = rim_w * (1 - frac * 0.7) / 2
        draw.line((cx - span, y, cx + span, y), fill=SEAM_DARK, width=stroke)

    return _finish(img)


def concept_stylized_net() -> Image.Image:
    """2. An abstract diamond-lattice net, no rim, no ball."""
    img, draw, hi = _canvas()
    cx = hi // 2
    top_y = round(hi * 0.18)
    bottom_y = round(hi * 0.86)
    top_half_w = round(hi * 0.34)
    stroke = max(2, round(hi * 0.018))

    rows = 6
    # Cone silhouette: width narrows linearly from top to bottom.
    for row in range(rows):
        t0 = row / rows
        t1 = (row + 1) / rows
        y0 = top_y + t0 * (bottom_y - top_y)
        y1 = top_y + t1 * (bottom_y - top_y)
        w0 = top_half_w * (1 - t0 * 0.82)
        w1 = top_half_w * (1 - t1 * 0.82)
        cols = rows - row + 2
        left0, left1 = cx - w0, cx - w1
        step0, step1 = (2 * w0) / cols, (2 * w1) / cols
        for col in range(cols + 1):
            xA = left0 + col * step0
            xB = left1 + col * step1
            color = ORANGE if (row + col) % 2 == 0 else ORANGE_LIGHT
            draw.line((xA, y0, xB, y1), fill=color, width=stroke)
            if col < cols:
                xA2 = left0 + (col + 1) * step0
                draw.line((xA2, y0, xB, y1), fill=color, width=stroke)

    # Rim bar at the top, anchoring the net visually.
    draw.line(
        (cx - top_half_w * 1.05, top_y, cx + top_half_w * 1.05, top_y),
        fill=CHALK,
        width=round(stroke * 1.6),
    )
    return _finish(img)


def concept_pin_ball() -> Image.Image:
    """3. A map pin fused with a basketball (seams inside the pin's head)."""
    img, draw, hi = _canvas()
    cx = hi // 2
    head_r = round(hi * 0.3)
    head_cy = round(hi * 0.36)

    tip_y = round(hi * 0.88)
    tip_half_w = head_r * 0.42
    draw.polygon(
        [
            (cx - tip_half_w, head_cy + head_r * 0.55),
            (cx + tip_half_w, head_cy + head_r * 0.55),
            (cx, tip_y),
        ],
        fill=ORANGE,
    )
    draw.ellipse(
        (cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r),
        fill=ORANGE,
    )

    # Basketball seams inside the pin's circular head only.
    seam_w = max(2, round(hi * 0.02))
    draw.line(
        (cx, head_cy - head_r, cx, head_cy + head_r * 0.6),
        fill=SEAM_DARK,
        width=seam_w,
    )
    draw.line(
        (cx - head_r, head_cy, cx + head_r, head_cy),
        fill=SEAM_DARK,
        width=seam_w,
    )
    offset = round(head_r * 0.85)
    for direction in (-1, 1):
        arc_cx = cx + direction * offset
        bbox = (arc_cx - head_r, head_cy - head_r, arc_cx + head_r, head_cy + head_r)
        start, end = (-42, 42) if direction < 0 else (138, 222)
        draw.arc(bbox, start, end, fill=SEAM_DARK, width=seam_w)

    # Clip seams (and the polygon tip's square corners) to the pin silhouette.
    mask = Image.new("L", img.size, 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.polygon(
        [
            (cx - tip_half_w, head_cy + head_r * 0.55),
            (cx + tip_half_w, head_cy + head_r * 0.55),
            (cx, tip_y),
        ],
        fill=255,
    )
    mdraw.ellipse(
        (cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r),
        fill=255,
    )
    # Small white dot at the pin's center, like a map-pin hole, on top.
    hole_r = round(head_r * 0.16)
    transparent = Image.new("RGBA", img.size, (0, 0, 0, 0))
    img = Image.composite(img, transparent, mask)
    draw = ImageDraw.Draw(img)
    return _finish(img)


def concept_abstract_geometric() -> Image.Image:
    """4. Abstract mark: a ball bouncing off the corner of a court tile."""
    img, draw, hi = _canvas()
    margin = round(hi * 0.14)
    tile_box = (margin, margin, hi - margin, hi - margin)
    draw.rounded_rectangle(tile_box, radius=round(hi * 0.14), fill=CHALK)

    ball_r = round(hi * 0.26)
    ball_cx, ball_cy = hi - margin - round(ball_r * 0.35), margin + round(ball_r * 0.35)
    draw.ellipse(
        (ball_cx - ball_r, ball_cy - ball_r, ball_cx + ball_r, ball_cy + ball_r),
        fill=ORANGE,
    )

    # Teal accent arc, bottom-left, echoing a three-point line.
    arc_r = round(hi * 0.46)
    arc_cx, arc_cy = margin - round(arc_r * 0.3), hi - margin + round(arc_r * 0.3)
    stroke = max(2, round(hi * 0.028))
    draw.arc(
        (arc_cx - arc_r, arc_cy - arc_r, arc_cx + arc_r, arc_cy + arc_r),
        260,
        350,
        fill=TEAL,
        width=stroke,
    )
    return _finish(img)


def concept_top_down_hoop() -> Image.Image:
    """5. A hoop seen from directly above: rim ring + woven net chords."""
    img, draw, hi = _canvas()
    cx = cy = hi // 2
    r = round(hi * 0.36)
    ring_w = round(hi * 0.075)

    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=ORANGE, width=ring_w)

    # Net seen from above: chords across the opening, offset from center
    # so they read as a woven lattice rather than a single asterisk.
    inner_r = r - ring_w
    stroke = max(2, round(hi * 0.014))
    chords = 8
    for i in range(chords):
        angle = (2 * math.pi / chords) * i
        x1 = cx + inner_r * math.cos(angle)
        y1 = cy + inner_r * math.sin(angle)
        x2 = cx - inner_r * math.cos(angle) * 0.35
        y2 = cy - inner_r * math.sin(angle) * 0.35
        draw.line((x1, y1, x2, y2), fill=SEAM_DARK, width=stroke)

    center_r = round(inner_r * 0.14)
    draw.ellipse(
        (cx - center_r, cy - center_r, cx + center_r, cy + center_r),
        fill=SEAM_DARK,
    )

    # Clip the net chords to the ring's inner opening so nothing spills
    # past the rim.
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse(
        (cx - r, cy - r, cx + r, cy + r), fill=255
    )
    transparent = Image.new("RGBA", img.size, (0, 0, 0, 0))
    img = Image.composite(img, transparent, mask)
    return _finish(img)


CONCEPTS: dict[str, tuple[str, Callable[[], Image.Image]]] = {
    "1_front_hoop": ("Hoop seen from the front", concept_front_hoop),
    "2_stylized_net": ("Stylized net", concept_stylized_net),
    "3_pin_ball": ("Map marker + ball", concept_pin_ball),
    "4_abstract_geometric": ("Abstract geometric shape", concept_abstract_geometric),
    "5_top_down_hoop": ("Rim seen from above", concept_top_down_hoop),
}


def _preview_variants(icon: Image.Image, name: str) -> None:
    on_dark = Image.new("RGBA", icon.size, ASPHALT)
    on_dark.alpha_composite(icon)
    on_light = Image.new("RGBA", icon.size, CHALK)
    on_light.alpha_composite(icon)

    small = on_dark.resize((48, 48), Image.LANCZOS)
    small.save(OUT_DIR / f"{name}_48.png")

    grayscale = on_dark.convert("L").convert("RGBA")
    grayscale_small = grayscale.resize((48, 48), Image.LANCZOS)
    grayscale_small.save(OUT_DIR / f"{name}_48_grayscale.png")
    grayscale.resize((256, 256), Image.LANCZOS).save(
        OUT_DIR / f"{name}_256_grayscale.png"
    )

    on_light.save(OUT_DIR / f"{name}_on_light.png")


def make_contact_sheet() -> None:
    cols = len(CONCEPTS)
    cell = 340
    sheet = Image.new("RGBA", (cell * cols, cell * 2 + 40), CHALK)
    draw = ImageDraw.Draw(sheet)
    for i, (name, (label, _fn)) in enumerate(CONCEPTS.items()):
        icon = Image.open(OUT_DIR / f"{name}.png").convert("RGBA")
        on_dark = Image.new("RGBA", icon.size, ASPHALT)
        on_dark.alpha_composite(icon)
        thumb = on_dark.resize((cell - 20, cell - 20), Image.LANCZOS)
        sheet.paste(thumb, (i * cell + 10, 10))

        gray = Image.open(OUT_DIR / f"{name}_256_grayscale.png").convert("RGBA")
        gray_thumb = gray.resize((cell - 20, cell - 20), Image.LANCZOS)
        sheet.paste(gray_thumb, (i * cell + 10, cell + 10))

        draw.text((i * cell + 10, cell * 2 + 14), f"{i + 1}. {label}", fill=(0, 0, 0, 255))
    sheet.convert("RGB").save(OUT_DIR / "icon_concepts_contact_sheet.png")


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (label, fn) in CONCEPTS.items():
        icon = fn()
        icon.save(OUT_DIR / f"{name}.png")
        _preview_variants(icon, name)
        print(f"Wrote {name}.png ({label})")
    make_contact_sheet()
    print(f"Wrote {OUT_DIR / 'icon_concepts_contact_sheet.png'}")
