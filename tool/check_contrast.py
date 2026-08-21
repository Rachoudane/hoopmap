"""Computes WCAG 2.x contrast ratios for every text/background pair used
by the app's theme (lib/core/theme/app_colors.dart), and flags anything
under the AA thresholds (4.5:1 for normal text, 3:1 for large/bold text
or non-text UI like icons/outlines).

This is a standalone audit tool with the palette's hex values copied in
(kept in sync by hand — there are few enough pairs that duplicating them
here is simpler than parsing Dart). Run after any palette change:
    python tool/check_contrast.py
"""

from __future__ import annotations


def _linear(c: float) -> float:
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_color: str) -> float:
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i : i + 2], 16) for i in (0, 2, 4))
    r, g, b = _linear(r), _linear(g), _linear(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(hex_a: str, hex_b: str) -> float:
    la, lb = relative_luminance(hex_a), relative_luminance(hex_b)
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


# Palette, matching lib/core/theme/app_colors.dart.
BALL_ORANGE = "#B74D14"
BALL_ORANGE_LIGHT = "#FF8A47"
COURT_TEAL = "#177A76"
COURT_TEAL_LIGHT = "#4BC9C3"
ASPHALT = "#14171B"
ASPHALT_SURFACE = "#1D2126"
ASPHALT_SURFACE_ELEVATED = "#262B31"
ASPHALT_OUTLINE = "#3A4048"
CHALK = "#F6F3EE"
CHALK_SURFACE = "#FFFFFF"
CHALK_SURFACE_ELEVATED = "#FBF9F5"
CHALK_OUTLINE = "#DDD8CF"
TEXT_DARK = "#1A1A18"
TEXT_DARK_SECONDARY = "#5B5F66"
TEXT_LIGHT = "#F2F0EC"
TEXT_LIGHT_SECONDARY = "#A7ACB3"
ERROR = "#C53E2A"
ERROR_DARK = "#FF6B57"
WHITE = "#FFFFFF"

# (label, foreground, background, "normal" | "large") — held to 4.5:1
# ("normal") everywhere text is involved, even bold button labels that
# WCAG would otherwise exempt down to 3:1 as "large text": the project
# deliberately holds itself to the stricter bar throughout. "large" is
# used only for genuinely non-text UI (outlines), per WCAG 1.4.11.
PAIRS = [
    # Light theme
    ("light: button label on primary (ElevatedButton)", WHITE, BALL_ORANGE, "normal"),
    ("light: onSecondary on secondary", WHITE, COURT_TEAL, "normal"),
    ("light: onError on error", WHITE, ERROR, "normal"),
    ("light: body text on surface", TEXT_DARK, CHALK_SURFACE, "normal"),
    ("light: body text on scaffold bg", TEXT_DARK, CHALK, "normal"),
    (
        "light: secondary text on surfaceContainerHighest",
        TEXT_DARK_SECONDARY,
        CHALK_SURFACE_ELEVATED,
        "normal",
    ),
    ("light: secondary text on scaffold bg", TEXT_DARK_SECONDARY, CHALK, "normal"),
    (
        "light: primary text on scaffold bg (distance label)",
        BALL_ORANGE,
        CHALK,
        "normal",
    ),
    (
        "light: primary text on surfaceContainerHighest (distance label on card)",
        BALL_ORANGE,
        CHALK_SURFACE_ELEVATED,
        "normal",
    ),
    ("light: outline on scaffold bg (non-text UI)", CHALK_OUTLINE, CHALK, "large"),
    # Dark theme
    (
        "dark: button label on primary (ElevatedButton)",
        ASPHALT,
        BALL_ORANGE_LIGHT,
        "normal",
    ),
    ("dark: onSecondary on secondary", ASPHALT, COURT_TEAL_LIGHT, "normal"),
    ("dark: onError on error", ASPHALT, ERROR_DARK, "normal"),
    ("dark: body text on surface", TEXT_LIGHT, ASPHALT_SURFACE, "normal"),
    ("dark: body text on scaffold bg", TEXT_LIGHT, ASPHALT, "normal"),
    (
        "dark: secondary text on surfaceContainerHighest",
        TEXT_LIGHT_SECONDARY,
        ASPHALT_SURFACE_ELEVATED,
        "normal",
    ),
    ("dark: secondary text on scaffold bg", TEXT_LIGHT_SECONDARY, ASPHALT, "normal"),
    (
        "dark: primary text on scaffold bg (distance label)",
        BALL_ORANGE_LIGHT,
        ASPHALT,
        "normal",
    ),
    (
        "dark: primary text on surfaceContainerHighest (distance label on card)",
        BALL_ORANGE_LIGHT,
        ASPHALT_SURFACE_ELEVATED,
        "normal",
    ),
    ("dark: outline on scaffold bg (non-text UI)", ASPHALT_OUTLINE, ASPHALT, "large"),
]

THRESHOLDS = {"normal": 4.5, "large": 3.0}


def main() -> None:
    failures = []
    for label, fg, bg, kind in PAIRS:
        ratio = contrast_ratio(fg, bg)
        threshold = THRESHOLDS[kind]
        status = "OK" if ratio >= threshold else "FAIL"
        if status == "FAIL":
            failures.append(label)
        print(f"[{status}] {label}: {ratio:.2f}:1 (needs {threshold}:1, {fg} on {bg})")

    print()
    if failures:
        print(f"{len(failures)} pair(s) below threshold:")
        for label in failures:
            print(f"  - {label}")
    else:
        print("All pairs meet their WCAG AA threshold.")


if __name__ == "__main__":
    main()
