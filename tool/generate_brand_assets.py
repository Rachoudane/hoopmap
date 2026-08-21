"""Generates Hoopmap's app icon and splash-screen artwork.

The mark is a map pin fused with a basketball (seams inside the pin's
head): of the five concepts explored in tool/generate_icon_concepts.py
(see design/icons/), it was the only one that stayed legible at 48x48
and in grayscale, and the only one that visually communicates both what
the app does (locate) and what it's about (basketball). No external
assets or third-party logos are used; everything is rendered at 4x and
downsampled for anti-aliasing.

Run from the repo root:
    python tool/generate_brand_assets.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = REPO_ROOT / "assets" / "icon"
SPLASH_DIR = REPO_ROOT / "assets" / "splash"

PIN_ORANGE = (242, 102, 26, 255)  # matches AppColors.brandOrange
SEAM_DARK = (28, 20, 12, 255)  # warm near-black, reads as "leather" seam
ASPHALT_DARK = (20, 23, 27, 255)  # matches AppColors.asphalt (dark bg)

SUPERSAMPLE = 4


def _new_canvas(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    hi_res = size * SUPERSAMPLE
    image = Image.new("RGBA", (hi_res, hi_res), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), hi_res


def _draw_pin_ball(hi: int, head_r_ratio: float) -> Image.Image:
    """Draws the map-pin-plus-basketball mark, sized so the pin's head has
    radius `head_r_ratio * hi`, on a transparent canvas of side `hi`."""
    image = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    cx = hi // 2
    head_r = round(hi * head_r_ratio)
    head_cy = round(hi * 0.44)
    tip_y = head_cy + round(head_r * 1.75)
    tip_half_w = head_r * 0.42

    pin_polygon = [
        (cx - tip_half_w, head_cy + head_r * 0.55),
        (cx + tip_half_w, head_cy + head_r * 0.55),
        (cx, tip_y),
    ]
    draw.polygon(pin_polygon, fill=PIN_ORANGE)
    draw.ellipse(
        (cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r),
        fill=PIN_ORANGE,
    )

    # Basketball seams inside the pin's circular head.
    seam_w = max(2, round(hi * 0.018))
    draw.line(
        (cx, head_cy - head_r, cx, head_cy + head_r * 0.6),
        fill=SEAM_DARK,
        width=seam_w,
    )
    draw.line((cx - head_r, head_cy, cx + head_r, head_cy), fill=SEAM_DARK, width=seam_w)
    offset = round(head_r * 0.85)
    for direction, start, end in ((-1, -42, 42), (1, 138, 222)):
        arc_cx = cx + direction * offset
        bbox = (arc_cx - head_r, head_cy - head_r, arc_cx + head_r, head_cy + head_r)
        draw.arc(bbox, start, end, fill=SEAM_DARK, width=seam_w)

    # Clip everything to the pin's silhouette (the arcs' bounding boxes and
    # the polygon corners extend past it).
    mask = Image.new("L", image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(pin_polygon, fill=255)
    mask_draw.ellipse(
        (cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r), fill=255
    )
    transparent = Image.new("RGBA", image.size, (0, 0, 0, 0))
    return Image.composite(image, transparent, mask)


def _pin_ball_layer(size: int, head_r_ratio: float) -> Image.Image:
    image, _, hi = _new_canvas(size)
    image = _draw_pin_ball(hi, head_r_ratio)
    return image.resize((size, size), Image.LANCZOS)


def make_icon() -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    size = 1024

    # Full launcher icon: opaque asphalt background, mark filling most of
    # the frame. Used for the legacy (non-adaptive) launcher icon.
    background = Image.new("RGBA", (size, size), ASPHALT_DARK)
    mark = _pin_ball_layer(size, head_r_ratio=0.24)
    background.alpha_composite(mark)
    background.convert("RGB").save(ICON_DIR / "icon.png")

    # Adaptive icon foreground: transparent background, mark sized to sit
    # within Android's adaptive-icon safe zone (~66% of the canvas).
    foreground = _pin_ball_layer(size, head_r_ratio=0.17)
    foreground.save(ICON_DIR / "icon_foreground.png")

    print(f"Wrote {ICON_DIR / 'icon.png'}")
    print(f"Wrote {ICON_DIR / 'icon_foreground.png'}")


def make_splash() -> None:
    SPLASH_DIR.mkdir(parents=True, exist_ok=True)
    size = 640
    mark = _pin_ball_layer(size, head_r_ratio=0.26)

    # Same mark for light and dark splash: the orange pin has enough
    # contrast against both the off-white and asphalt background colors
    # declared in pubspec.yaml's flutter_native_splash section.
    mark.save(SPLASH_DIR / "splash_logo.png")
    mark.save(SPLASH_DIR / "splash_logo_dark.png")

    print(f"Wrote {SPLASH_DIR / 'splash_logo.png'}")
    print(f"Wrote {SPLASH_DIR / 'splash_logo_dark.png'}")


if __name__ == "__main__":
    make_icon()
    make_splash()
