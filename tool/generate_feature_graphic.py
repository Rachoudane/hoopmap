"""Generates the Play Store feature graphic (1024x500).

Reuses the icon's map-pin-plus-basketball mark (see generate_brand_assets.py
and generate_icon_concepts.py's concept_pin_ball) at feature-graphic scale,
paired with the wordmark and a short tagline. Same palette as the rest of
the brand assets — no new colors introduced here.

Run from the repo root:
    python tool/generate_feature_graphic.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "design" / "play-store"
FONT_DIR = REPO_ROOT / "assets" / "fonts"
ICON_FOREGROUND = REPO_ROOT / "assets" / "icon" / "icon_foreground.png"

W, H = 1024, 500

ASPHALT = (20, 23, 27, 255)
ASPHALT_SURFACE = (29, 33, 38, 255)
CHALK = (246, 243, 238, 255)
CHALK_SECONDARY = (167, 172, 179, 255)


def _oswald(weight: str, size: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_DIR / "Oswald-Variable.ttf"), size)
    font.set_variation_by_name(weight)
    return font


def _inter(weight: str, size: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_DIR / "Inter-Variable.ttf"), size)
    font.set_variation_by_name(weight)
    return font


def _load_mark(target_height: int) -> Image.Image:
    """Loads the app's actual (validated, unmodified) icon mark, cropped to
    its opaque content and scaled to `target_height`, so the feature
    graphic uses the exact same glyph as the launcher icon."""
    icon = Image.open(ICON_FOREGROUND).convert("RGBA")
    bbox = icon.getbbox()
    icon = icon.crop(bbox)
    scale = target_height / icon.height
    new_size = (round(icon.width * scale), target_height)
    return icon.resize(new_size, Image.LANCZOS)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (W, H), ASPHALT)
    draw = ImageDraw.Draw(canvas)

    # Subtle darker panel on the right, echoing a map viewport, so the
    # graphic reads as "place-finding" even before the copy is parsed.
    draw.rectangle((W * 0.62, 0, W, H), fill=ASPHALT_SURFACE)
    for x in range(int(W * 0.62), W, 64):
        draw.line((x, 0, x, H), fill=(58, 64, 72, 60), width=2)
    for y in range(0, H, 64):
        draw.line((W * 0.62, y, W, y), fill=(58, 64, 72, 60), width=2)

    mark = _load_mark(target_height=340)
    canvas.alpha_composite(
        mark, (int(W * 0.68) - mark.width // 2, H // 2 - mark.height // 2)
    )

    wordmark_font = _oswald("Bold", 92)
    draw.text((72, 138), "Hoopmap", font=wordmark_font, fill=CHALK)

    tagline_font = _inter("Medium", 32)
    draw.text(
        (76, 306),
        "Find basketball courts,\nwherever you are",
        font=tagline_font,
        fill=CHALK_SECONDARY,
        spacing=12,
    )

    out_path = OUT_DIR / "feature-graphic.png"
    canvas.convert("RGB").save(out_path)
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
