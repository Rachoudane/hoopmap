"""Generates dressed Play Store screenshots from the raw device captures.

Reads every PNG in design/play-store/screenshots/raw/, places it on a
branded 1080x1920 asphalt background with a short headline in Oswald Bold,
and writes the result to design/play-store/screenshots/. Uses the same
palette as lib/core/theme/app_colors.dart and the icon/splash generator
(tool/generate_brand_assets.py) — no new colors introduced here.

Run from the repo root:
    python tool/generate_play_store_screenshots.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = REPO_ROOT / "design" / "play-store" / "screenshots" / "raw"
OUT_DIR = REPO_ROOT / "design" / "play-store" / "screenshots"
FONT_DIR = REPO_ROOT / "assets" / "fonts"

CANVAS_W = 1080
CANVAS_H = 1920

ASPHALT = (20, 23, 27, 255)  # AppColors.asphalt
BALL_ORANGE = (242, 102, 26, 255)  # raw brand hue, AppColors comment
CHALK = (246, 243, 238, 255)  # AppColors.chalk
CHALK_SECONDARY = (167, 172, 179, 255)  # AppColors.textLightSecondary

# (raw filename stem, headline, device-frame corner radius of the source
# screenshot itself — all raw captures share the same on-device radius, so
# this is constant, kept as a named value for clarity)
SCREENSHOTS: list[tuple[str, str]] = [
    ("01_onboarding", "Find courts anywhere"),
    ("02_list", "Sorted by distance"),
    ("03_map", "Courts on the map"),
    ("04_marker_preview", "Quick court preview"),
    ("05_detail_with_photo", "See real court photos"),
    ("06_detail_no_photo", "Full court details"),
    ("07_location_picker", "Pick the exact spot"),
    ("08_add_court_filled", "Add missing courts"),
]

MARGIN_X = 64
TOP_PADDING = 96
HEADLINE_SIZE = 76
HEADLINE_MAX_WIDTH = CANVAS_W - 2 * MARGIN_X
SCREEN_CORNER_RADIUS = 56
WORDMARK_SIZE = 40


def _oswald(weight: str, size: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_DIR / "Oswald-Variable.ttf"), size)
    font.set_variation_by_name(weight)
    return font


def _inter(weight: str, size: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_DIR / "Inter-Variable.ttf"), size)
    font.set_variation_by_name(weight)
    return font


def _wrap_to_width(
    draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int
) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=font) <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def _rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0], size[1]), radius=radius, fill=255
    )
    return mask


def _draw_wordmark(canvas: Image.Image, draw: ImageDraw.ImageDraw) -> None:
    """A tiny basketball glyph + "Hoopmap" in the top-left corner, echoing
    the app icon without duplicating its generation code (that mark is a
    map-pin silhouette; here a plain dot reads fine at this size)."""
    dot_r = 12
    dot_cx = MARGIN_X + dot_r
    dot_cy = TOP_PADDING // 2 + 6
    draw.ellipse(
        (dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r),
        fill=BALL_ORANGE,
    )
    font = _oswald("SemiBold", WORDMARK_SIZE)
    draw.text(
        (dot_cx + dot_r + 16, dot_cy),
        "Hoopmap",
        font=font,
        fill=CHALK,
        anchor="lm",
    )


def _compose(stem: str, headline: str) -> Image.Image:
    raw_path = RAW_DIR / f"{stem}.png"
    screenshot = Image.open(raw_path).convert("RGBA")

    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), ASPHALT)
    draw = ImageDraw.Draw(canvas)

    _draw_wordmark(canvas, draw)

    headline_font = _oswald("Bold", HEADLINE_SIZE)
    lines = _wrap_to_width(draw, headline, headline_font, HEADLINE_MAX_WIDTH)
    line_height = int(HEADLINE_SIZE * 1.15)
    text_top = TOP_PADDING + 70
    for i, line in enumerate(lines):
        draw.text(
            (CANVAS_W // 2, text_top + i * line_height),
            line,
            font=headline_font,
            fill=CHALK,
            anchor="ma",
        )
    text_bottom = text_top + len(lines) * line_height

    # Fit the screenshot into the remaining space, leaving even side
    # margins and breathing room above the bottom edge.
    available_top = text_bottom + 56
    available_bottom = CANVAS_H - 72
    available_w = CANVAS_W - 2 * MARGIN_X
    available_h = available_bottom - available_top

    scale = min(available_w / screenshot.width, available_h / screenshot.height)
    new_size = (round(screenshot.width * scale), round(screenshot.height * scale))
    resized = screenshot.resize(new_size, Image.LANCZOS)

    mask = _rounded_mask(new_size, SCREEN_CORNER_RADIUS)
    paste_x = (CANVAS_W - new_size[0]) // 2
    paste_y = available_top + (available_h - new_size[1]) // 2

    # Soft shadow behind the device screenshot for separation from the flat
    # background.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (
            paste_x - 6,
            paste_y - 2,
            paste_x + new_size[0] + 6,
            paste_y + new_size[1] + 14,
        ),
        radius=SCREEN_CORNER_RADIUS + 6,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(18))
    canvas.alpha_composite(shadow)

    canvas.paste(resized, (paste_x, paste_y), mask)

    # Thin outline so light-content screenshots don't blend into the
    # background at the edge.
    outline = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(outline).rounded_rectangle(
        (paste_x, paste_y, paste_x + new_size[0], paste_y + new_size[1]),
        radius=SCREEN_CORNER_RADIUS,
        outline=(255, 255, 255, 40),
        width=2,
    )
    canvas.alpha_composite(outline)

    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for stem, headline in SCREENSHOTS:
        canvas = _compose(stem, headline)
        out_path = OUT_DIR / f"{stem}.png"
        canvas.convert("RGB").save(out_path)
        print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
