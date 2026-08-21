"""Generates hoopmap's app icon and splash-screen artwork.

Draws a simple, flat basketball mark (an orange disc with the classic
seam lines) with no external assets or third-party logos. Everything is
rendered at 4x and downsampled for anti-aliasing.

Run from the repo root:
    python tool/generate_brand_assets.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = REPO_ROOT / "assets" / "icon"
SPLASH_DIR = REPO_ROOT / "assets" / "splash"

BALL_ORANGE = (242, 102, 26, 255)  # matches AppColors.brandOrange
SEAM_DARK = (28, 20, 12, 255)  # warm near-black, reads as "leather" seam
ASPHALT_DARK = (20, 23, 27, 255)  # matches AppColors.asphalt (dark bg)

SUPERSAMPLE = 4


def _new_canvas(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    hi_res = size * SUPERSAMPLE
    image = Image.new("RGBA", (hi_res, hi_res), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), hi_res


def _draw_basketball(
    draw: ImageDraw.ImageDraw,
    center: tuple[int, int],
    radius: int,
    ball_color: tuple[int, int, int, int],
    seam_color: tuple[int, int, int, int],
) -> None:
    cx, cy = center
    stroke = max(2, round(radius * 0.052))

    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=ball_color,
    )

    # Vertical seam, full height of the ball.
    draw.line((cx, cy - radius, cx, cy + radius), fill=seam_color, width=stroke)

    # Horizontal seam, full width of the ball.
    draw.line((cx - radius, cy, cx + radius, cy), fill=seam_color, width=stroke)

    # Two curved seams: arcs of circles offset left/right of center, clipped
    # to the ball's silhouette by drawing only the portion of the arc that
    # falls inside it (the classic flat-basketball illustration trick).
    offset = round(radius * 0.92)
    for direction, angle_start, angle_end in ((-1, -46, 46), (1, 134, 226)):
        arc_cx = cx + direction * offset
        bbox = (
            arc_cx - radius,
            cy - radius,
            arc_cx + radius,
            cy + radius,
        )
        draw.arc(bbox, angle_start, angle_end, fill=seam_color, width=stroke)


def _basketball_layer(size: int, radius_ratio: float) -> Image.Image:
    image, draw, hi_res = _new_canvas(size)
    center = (hi_res // 2, hi_res // 2)
    radius = round(hi_res * radius_ratio)
    _draw_basketball(draw, center, radius, BALL_ORANGE, SEAM_DARK)

    # Clip anything drawn outside the ball's circle (the seam arcs' bounding
    # boxes are larger than the ball itself).
    clip_mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(clip_mask).ellipse(
        (
            center[0] - radius,
            center[1] - radius,
            center[0] + radius,
            center[1] + radius,
        ),
        fill=255,
    )
    transparent = Image.new("RGBA", image.size, (0, 0, 0, 0))
    image = Image.composite(image, transparent, clip_mask)

    return image.resize((size, size), Image.LANCZOS)


def make_icon() -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    size = 1024

    # Full launcher icon: opaque asphalt background, ball fills most of the
    # frame. Used for the legacy (non-adaptive) launcher icon.
    background = Image.new("RGBA", (size, size), ASPHALT_DARK)
    ball = _basketball_layer(size, radius_ratio=0.42)
    background.alpha_composite(ball)
    background.convert("RGB").save(ICON_DIR / "icon.png")

    # Adaptive icon foreground: transparent background, ball sized to sit
    # within Android's adaptive-icon safe zone (~66% of the canvas).
    foreground = _basketball_layer(size, radius_ratio=0.30)
    foreground.save(ICON_DIR / "icon_foreground.png")

    print(f"Wrote {ICON_DIR / 'icon.png'}")
    print(f"Wrote {ICON_DIR / 'icon_foreground.png'}")


def make_splash() -> None:
    SPLASH_DIR.mkdir(parents=True, exist_ok=True)
    size = 640
    mark = _basketball_layer(size, radius_ratio=0.46)

    # Same mark for light and dark splash: the orange ball has enough
    # contrast against both the off-white and asphalt background colors
    # declared in pubspec.yaml's flutter_native_splash section.
    mark.save(SPLASH_DIR / "splash_logo.png")
    mark.save(SPLASH_DIR / "splash_logo_dark.png")

    print(f"Wrote {SPLASH_DIR / 'splash_logo.png'}")
    print(f"Wrote {SPLASH_DIR / 'splash_logo_dark.png'}")


if __name__ == "__main__":
    make_icon()
    make_splash()
