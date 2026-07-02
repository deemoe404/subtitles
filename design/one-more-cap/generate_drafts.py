#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
ICONTOOL = Path(
    "/Users/sam/Applications/Xcode-beta.app/Contents/Applications/"
    "Icon Composer.app/Contents/Executables/ictool"
)
TOTAL_PANEL_COUNT = 6
PANEL_BOUNDARY_PHASE_DEGREES = 30.0
HEMISPHERE_PITCH_DEGREES = 8.0
CAMERA_FRONT_AZIMUTH_DEGREES = 60.0
VISIBLE_BOUNDARY_DEPTH_THRESHOLD = 0.25


@dataclass(frozen=True)
class Palette:
    light_bg: str
    dark_bg: str
    light_crown: str
    dark_crown: str
    light_panel: str
    dark_panel: str
    light_brim: str
    dark_brim: str
    light_bar: str
    dark_bar: str


@dataclass(frozen=True)
class Variant:
    slug: str
    title: str
    crown_shift_y: float
    crown_scale_x: float
    brim_len: float
    brim_y: float
    bar_scale: float
    minimal_panels: bool
    palette: Palette


VARIANTS = [
    Variant(
        slug="a-balanced",
        title="Balanced",
        crown_shift_y=0,
        crown_scale_x=1.0,
        brim_len=1.0,
        brim_y=0,
        bar_scale=1.0,
        minimal_panels=False,
        palette=Palette(
            light_bg="#d86a4d",
            dark_bg="#151b22",
            light_crown="#fff3d5",
            dark_crown="#242c36",
            light_panel="#eadfc6",
            dark_panel="#303946",
            light_brim="#f37555",
            dark_brim="#14a8bb",
            light_bar="#fff8e8",
            dark_bar="#fff6e6",
        ),
    ),
    Variant(
        slug="b-long-brim",
        title="Long Brim",
        crown_shift_y=12,
        crown_scale_x=0.96,
        brim_len=1.12,
        brim_y=8,
        bar_scale=1.04,
        minimal_panels=False,
        palette=Palette(
            light_bg="#d95f46",
            dark_bg="#111820",
            light_crown="#fff5dd",
            dark_crown="#222b35",
            light_panel="#e7ddc6",
            dark_panel="#343f4b",
            light_brim="#f47a55",
            dark_brim="#1bb7c9",
            light_bar="#fff9ec",
            dark_bar="#fff3de",
        ),
    ),
    Variant(
        slug="c-minimal",
        title="Minimal",
        crown_shift_y=8,
        crown_scale_x=0.94,
        brim_len=1.04,
        brim_y=5,
        bar_scale=0.96,
        minimal_panels=True,
        palette=Palette(
            light_bg="#e06f52",
            dark_bg="#11151a",
            light_crown="#fff0cf",
            dark_crown="#20262e",
            light_panel="#fff0cf",
            dark_panel="#20262e",
            light_brim="#f0845c",
            dark_brim="#19a4b8",
            light_bar="#fff8e8",
            dark_bar="#fff4e0",
        ),
    ),
]

MENU_VARIANTS = {
    "cap-bars-balanced": {"brim": 1.00, "crown": 1.00, "bars": 1.00, "x": 0.00},
    "cap-bars-wide": {"brim": 1.08, "crown": 0.96, "bars": 1.04, "x": -0.12},
    "cap-bars-compact": {"brim": 0.94, "crown": 0.94, "bars": 0.94, "x": 0.06},
    "cap-bars-minimal": {"brim": 1.00, "crown": 0.90, "bars": 0.92, "x": 0.02},
}


def hex_to_display_p3(hex_color: str) -> str:
    value = hex_color.lstrip("#")
    r = int(value[0:2], 16) / 255
    g = int(value[2:4], 16) / 255
    b = int(value[4:6], 16) / 255
    return f"display-p3:{r:.5f},{g:.5f},{b:.5f},1.00000"


def path_crown(variant: Variant) -> str:
    cy = variant.crown_shift_y
    sx = variant.crown_scale_x
    cx = 505

    def x(value: float) -> float:
        return cx + (value - cx) * sx

    return (
        f"M {x(248):.1f} {526+cy:.1f} "
        f"C {x(253):.1f} {407+cy:.1f}, {x(336):.1f} {307+cy:.1f}, {x(487):.1f} {292+cy:.1f} "
        f"C {x(626):.1f} {279+cy:.1f}, {x(731):.1f} {371+cy:.1f}, {x(754):.1f} {515+cy:.1f} "
        f"C {x(644):.1f} {498+cy:.1f}, {x(416):.1f} {500+cy:.1f}, {x(248):.1f} {526+cy:.1f} "
        "Z"
    )


def path_panel_left(variant: Variant) -> str:
    cy = variant.crown_shift_y
    sx = variant.crown_scale_x
    cx = 520

    def x(value: float) -> float:
        return cx + (value - cx) * sx

    return (
        f"M {x(309):.1f} {503+cy:.1f} "
        f"C {x(313):.1f} {388+cy:.1f}, {x(387):.1f} {318+cy:.1f}, {x(506):.1f} {318+cy:.1f} "
        f"L {x(506):.1f} {503+cy:.1f} Z"
    )


def path_panel_right(variant: Variant) -> str:
    cy = variant.crown_shift_y
    sx = variant.crown_scale_x
    cx = 520

    def x(value: float) -> float:
        return cx + (value - cx) * sx

    return (
        f"M {x(527):.1f} {319+cy:.1f} "
        f"C {x(625):.1f} {326+cy:.1f}, {x(691):.1f} {394+cy:.1f}, {x(706):.1f} {502+cy:.1f} "
        f"L {x(527):.1f} {502+cy:.1f} Z"
    )


def path_brim(variant: Variant) -> str:
    length = variant.brim_len
    y = 497 + variant.crown_shift_y + variant.brim_y
    x0 = 486
    x1 = x0 + 330 * length
    return (
        f"M {x0:.1f} {y:.1f} "
        f"C {x0+68:.1f} {y-18:.1f}, {x1-88:.1f} {y-9:.1f}, {x1:.1f} {y+5:.1f} "
        f"C {x1+27:.1f} {y+10:.1f}, {x1+26:.1f} {y+43:.1f}, {x1-3:.1f} {y+49:.1f} "
        f"C {x1-132:.1f} {y+62:.1f}, {x0+96:.1f} {y+59:.1f}, {x0:.1f} {y+44:.1f} "
        f"C {x0-21:.1f} {y+40:.1f}, {x0-19:.1f} {y+7:.1f}, {x0:.1f} {y:.1f} Z"
    )


def rounded_rect(x: float, y: float, width: float, height: float, radius: float) -> str:
    r = min(radius, width / 2, height / 2)
    return (
        f"M {x+r:.1f} {y:.1f} H {x+width-r:.1f} "
        f"C {x+width-r/2:.1f} {y:.1f}, {x+width:.1f} {y+r/2:.1f}, {x+width:.1f} {y+r:.1f} "
        f"V {y+height-r:.1f} "
        f"C {x+width:.1f} {y+height-r/2:.1f}, {x+width-r/2:.1f} {y+height:.1f}, {x+width-r:.1f} {y+height:.1f} "
        f"H {x+r:.1f} "
        f"C {x+r/2:.1f} {y+height:.1f}, {x:.1f} {y+height-r/2:.1f}, {x:.1f} {y+height-r:.1f} "
        f"V {y+r:.1f} "
        f"C {x:.1f} {y+r/2:.1f}, {x+r/2:.1f} {y:.1f}, {x+r:.1f} {y:.1f} Z"
    )


def svg_doc(paths: list[tuple[str, str, float]], shadow: bool = False) -> str:
    filters = ""
    attr = ""
    if shadow:
        filters = (
            "<defs><filter id=\"soft-shadow\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"150%\">"
            "<feDropShadow dx=\"0\" dy=\"14\" stdDeviation=\"12\" flood-color=\"#000000\" flood-opacity=\"0.22\"/>"
            "</filter></defs>"
        )
        attr = " filter=\"url(#soft-shadow)\""
    body = "\n".join(
        f"  <path d=\"{path}\" fill=\"{color}\" opacity=\"{opacity:.3f}\"/>" for path, color, opacity in paths
    )
    return (
        "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1024 1024\">\n"
        f"{filters}\n"
        f"<g{attr}>\n{body}\n</g>\n"
        "</svg>\n"
    )


def panel_boundary_phis() -> list[float]:
    step = 360.0 / TOTAL_PANEL_COUNT
    return [PANEL_BOUNDARY_PHASE_DEGREES + step * index for index in range(TOTAL_PANEL_COUNT)]


def relative_phi_radians(phi_degrees: float) -> float:
    return math.radians(phi_degrees - CAMERA_FRONT_AZIMUTH_DEGREES + 90.0)


def projected_meridian_points(variant: Variant, phi_degrees: float) -> list[tuple[float, float]]:
    """Project a hemisphere meridian into the current camera orientation."""
    cy = variant.crown_shift_y
    phi = relative_phi_radians(phi_degrees)
    pitch = math.radians(HEMISPHERE_PITCH_DEGREES)
    top_x = 520.0
    top_y = 295.0 + cy
    x_scale = 280.0 * variant.crown_scale_x
    y_scale = 190.0
    v_top = -math.cos(pitch)

    points: list[tuple[float, float]] = []
    for index in range(72):
        theta = (math.pi / 2) * (index / 71)
        sin_theta = math.sin(theta)
        cos_theta = math.cos(theta)
        u = sin_theta * math.cos(phi)
        depth = sin_theta * math.sin(phi)
        v = -cos_theta * math.cos(pitch) + depth * math.sin(pitch)
        points.append((
            top_x + x_scale * u,
            top_y + y_scale * (v - v_top),
        ))
    return points


def is_front_visible_boundary(phi_degrees: float) -> bool:
    phi = relative_phi_radians(phi_degrees)
    return math.sin(phi) >= VISIBLE_BOUNDARY_DEPTH_THRESHOLD


def strip_path(points: list[tuple[float, float]], width: float) -> str:
    left: list[tuple[float, float]] = []
    right: list[tuple[float, float]] = []

    for index, (x, y) in enumerate(points):
        if index == 0:
            x0, y0 = points[index]
            x1, y1 = points[index + 1]
        elif index == len(points) - 1:
            x0, y0 = points[index - 1]
            x1, y1 = points[index]
        else:
            x0, y0 = points[index - 1]
            x1, y1 = points[index + 1]

        dx = x1 - x0
        dy = y1 - y0
        length = math.hypot(dx, dy) or 1.0
        nx = -dy / length
        ny = dx / length
        t = index / max(1, len(points) - 1)
        half_width = width * (0.68 + 0.32 * t) / 2
        left.append((x + nx * half_width, y + ny * half_width))
        right.append((x - nx * half_width, y - ny * half_width))

    polygon = left + list(reversed(right))
    commands = [f"M {polygon[0][0]:.1f} {polygon[0][1]:.1f}"]
    commands.extend(f"L {x:.1f} {y:.1f}" for x, y in polygon[1:])
    commands.append("Z")
    return " ".join(commands)


def seam_svg(variant: Variant, color: str, opacity: float) -> str:
    path_elements: list[str] = []
    for phi in panel_boundary_phis():
        if not is_front_visible_boundary(phi):
            continue

        relative_phi = math.degrees(relative_phi_radians(phi))
        front_angle = abs(((relative_phi - 90.0 + 180.0) % 360.0) - 180.0)
        front_weight = max(0.0, 1.0 - front_angle / 120.0)
        line_opacity = opacity * (0.58 + 0.42 * front_weight)
        width = 6.8 + 1.2 * front_weight
        path_elements.append(
            f'    <path d="{strip_path(projected_meridian_points(variant, phi), width)}" '
            f'fill="{color}" opacity="{line_opacity:.3f}"/>'
        )
    paths = "\n".join(path_elements)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <clipPath id="crown-clip">
      <path d="{path_crown(variant)}"/>
    </clipPath>
  </defs>
  <g clip-path="url(#crown-clip)">
{paths}
  </g>
</svg>
"""


def make_layer_svgs(icon_dir: Path, variant: Variant, mode: str) -> list[str]:
    assets = icon_dir / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    p = variant.palette
    colors = {
        "light": {
            "crown": p.light_crown,
            "panel": p.light_panel,
            "brim": p.light_brim,
            "bar": p.light_bar,
        },
        "dark": {
            "crown": p.dark_crown,
            "panel": p.dark_panel,
            "brim": p.dark_brim,
            "bar": p.dark_bar,
        },
    }[mode]

    prefix = mode
    files: list[str] = []

    button = rounded_rect(488, 262 + variant.crown_shift_y, 64, 36, 18)
    (assets / f"{prefix}-button.svg").write_text(
        svg_doc([(button, colors["panel"], 1.0)], shadow=False),
        encoding="utf-8",
    )
    files.append(f"{prefix}-button.svg")

    crown_paths = [(path_crown(variant), colors["crown"], 1.0)]
    (assets / f"{prefix}-crown.svg").write_text(svg_doc(crown_paths, shadow=True), encoding="utf-8")
    files.append(f"{prefix}-crown.svg")

    seam_color = "#a3763e" if mode == "light" else "#8698a6"
    seam_opacity = 0.42 if mode == "light" else 0.48
    (assets / f"{prefix}-seam.svg").write_text(
        seam_svg(variant, seam_color, seam_opacity),
        encoding="utf-8",
    )
    files.append(f"{prefix}-seam.svg")

    (assets / f"{prefix}-brim.svg").write_text(
        svg_doc([(path_brim(variant), colors["brim"], 1.0)], shadow=True),
        encoding="utf-8",
    )
    files.append(f"{prefix}-brim.svg")

    short_width = 306 * variant.bar_scale
    long_width = 436 * variant.bar_scale
    gap_width = 24 * variant.bar_scale
    left_width = (long_width - gap_width) * 0.80
    right_width = (long_width - gap_width) * 0.20
    long_x = (1024 - long_width) / 2
    bars = [
        (rounded_rect((1024 - short_width) / 2, 626, short_width, 48, 23), colors["bar"], 1.0),
        (rounded_rect(long_x, 716, left_width, 50, 24), colors["bar"], 1.0),
        (rounded_rect(long_x + left_width + gap_width, 716, right_width, 50, 24), colors["bar"], 1.0),
    ]
    (assets / f"{prefix}-bars.svg").write_text(svg_doc(bars, shadow=True), encoding="utf-8")
    files.append(f"{prefix}-bars.svg")

    return files


def icon_json(variant: Variant) -> dict:
    layers: list[dict] = []
    order = ["button", "brim", "seam", "crown", "bars"]
    for mode in ["light", "dark"]:
        for part in order:
            visible = mode == "light"
            layer = {
                "image-name": f"{mode}-{part}.svg",
                "name": f"{mode}-{part}",
                "opacity-specializations": [
                    {
                        "value": 1 if visible else 0,
                    },
                    {
                        "appearance": "dark",
                        "value": 0 if visible else 1,
                    }
                ],
                "position": {
                    "scale": 1,
                    "translation-in-points": [0, 0],
                },
            }
            if part in {"brim", "bars"}:
                layer["glass"] = True
            layers.append(layer)

    return {
        "color-space-for-untagged-svg-colors": "display-p3",
        "fill": {
            "solid": hex_to_display_p3(variant.palette.light_bg),
            "fill-specializations": [
                {"value": {"solid": hex_to_display_p3(variant.palette.light_bg)}},
                {"appearance": "dark", "value": {"solid": hex_to_display_p3(variant.palette.dark_bg)}},
            ],
        },
        "groups": [
            {
                "layers": layers,
                "lighting": "combined",
                "shadow": {"kind": "neutral", "opacity": 0.45},
                "translucency": {"enabled": True, "value": 0.18},
                "material-strength": 0.35,
            }
        ],
        "supported-platforms": {"squares": ["macOS"]},
    }


def make_icon_bundle(variant: Variant) -> Path:
    icon_dir = ROOT / "icon-composer" / f"OneMoreCap-{variant.slug}.icon"
    if icon_dir.exists():
        shutil.rmtree(icon_dir)
    icon_dir.mkdir(parents=True)
    make_layer_svgs(icon_dir, variant, "light")
    make_layer_svgs(icon_dir, variant, "dark")
    (icon_dir / "icon.json").write_text(json.dumps(icon_json(variant), indent=2) + "\n", encoding="utf-8")
    return icon_dir


def menu_svg(name: str, factors: dict[str, float]) -> str:
    brim = factors["brim"]
    crown = factors["crown"]
    bars = factors["bars"]
    dx = factors["x"]
    cx = 8.75 + dx
    crown_w = 7.0 * crown
    crown_x = cx - crown_w / 2
    brim_w = 5.85 * brim
    brim_x = 8.00 + dx
    top_bar_w = 5.30 * bars
    bottom_bar_w = 7.80 * bars
    top_bar_x = 6.20 + dx
    bottom_bar_x = 4.92 + dx
    bottom_gap_w = 0.38 * bars
    bottom_left_w = (bottom_bar_w - bottom_gap_w) * 0.78
    bottom_right_w = (bottom_bar_w - bottom_gap_w) - bottom_left_w
    bottom_right_x = bottom_bar_x + bottom_left_w + bottom_gap_w
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">
  <path fill="black" d="M {crown_x:.2f} 9.30 C {crown_x+0.08:.2f} 6.68, {crown_x+2.18*crown:.2f} 5.04, {cx:.2f} 4.96 C {cx+2.56*crown:.2f} 4.88, {cx+3.92*crown:.2f} 6.62, {cx+4.02*crown:.2f} 9.16 C {cx+2.42*crown:.2f} 8.96, {crown_x+2.30*crown:.2f} 9.02, {crown_x:.2f} 9.30 Z"/>
  <path fill="black" d="M {cx-0.88:.2f} 4.80 C {cx-0.88:.2f} 4.42, {cx-0.50:.2f} 4.16, {cx+0.10:.2f} 4.16 C {cx+0.72:.2f} 4.16, {cx+1.08:.2f} 4.42, {cx+1.08:.2f} 4.80 V 5.08 H {cx-0.88:.2f} Z"/>
  <path fill="black" d="M {brim_x:.2f} 8.98 C {brim_x+1.20:.2f} 8.66, {brim_x+brim_w-1.08:.2f} 8.68, {brim_x+brim_w:.2f} 8.94 C {brim_x+brim_w+0.42:.2f} 9.04, {brim_x+brim_w+0.38:.2f} 9.68, {brim_x+brim_w-0.08:.2f} 9.78 H {brim_x:.2f} C {brim_x-0.38:.2f} 9.78, {brim_x-0.38:.2f} 9.12, {brim_x:.2f} 8.98 Z"/>
  <rect fill="black" x="{top_bar_x:.2f}" y="10.92" width="{top_bar_w:.2f}" height="1.18" rx="0.59"/>
  <rect fill="black" x="{bottom_bar_x:.2f}" y="13.04" width="{bottom_left_w:.2f}" height="1.28" rx="0.64"/>
  <rect fill="black" x="{bottom_right_x:.2f}" y="13.04" width="{bottom_right_w:.2f}" height="1.28" rx="0.64"/>
</svg>
"""


def make_menu_assets() -> None:
    menu_dir = ROOT / "menu-bar"
    preview_dir = ROOT / "previews" / "menu-bar"
    menu_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)
    for name, factors in MENU_VARIANTS.items():
        svg_path = menu_dir / f"{name}.svg"
        svg_path.write_text(menu_svg(name, factors), encoding="utf-8")
        for size in [18, 36, 72]:
            png_path = preview_dir / f"{name}-{size}.png"
            subprocess.run(
                ["qlmanage", "-t", "-s", str(size), "-o", str(preview_dir), str(svg_path)],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            thumb = preview_dir / f"{svg_path.name}.png"
            if thumb.exists():
                thumb.replace(png_path)


def export_icon_previews(icon_dir: Path) -> None:
    preview_dir = ROOT / "previews" / "app-icons"
    preview_dir.mkdir(parents=True, exist_ok=True)
    for rendition in ["Default", "Dark"]:
        out = preview_dir / f"{icon_dir.stem}-{rendition.lower()}.png"
        subprocess.run(
            [
                str(ICONTOOL),
                str(icon_dir),
                "--export-image",
                "--output-file",
                str(out),
                "--platform",
                "macOS",
                "--rendition",
                rendition,
                "--width",
                "512",
                "--height",
                "512",
                "--scale",
                "1",
            ],
            check=True,
        )


def make_index(icon_dirs: list[Path]) -> None:
    rows = []
    for icon_dir in icon_dirs:
        stem = icon_dir.stem
        rows.append(
            f"""
      <section class="row">
        <h2>{stem}</h2>
        <img src="previews/app-icons/{stem}-default.png" alt="{stem} default">
        <img src="previews/app-icons/{stem}-dark.png" alt="{stem} dark">
      </section>
"""
        )
    menu_items = []
    for name in MENU_VARIANTS:
        menu_items.append(
            f"""
      <section class="menu">
        <h2>{name}</h2>
        <img src="previews/menu-bar/{name}-18.png" alt="{name} 18">
        <img src="previews/menu-bar/{name}-36.png" alt="{name} 36">
        <img src="previews/menu-bar/{name}-72.png" alt="{name} 72">
      </section>
"""
        )
    html = f"""<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>One More Cap Icon Drafts</title>
<style>
  body {{ margin: 32px; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; background: #f5f5f5; color: #111; }}
  h1 {{ font-size: 24px; margin: 0 0 22px; }}
  h2 {{ width: 260px; font-size: 13px; font-weight: 600; margin: 0; color: #555; }}
  .row, .menu {{ display: flex; align-items: center; gap: 18px; margin: 16px 0; }}
  .row img {{ width: 176px; height: 176px; border-radius: 40px; box-shadow: 0 12px 28px rgba(0,0,0,.12); }}
  .menu img {{ image-rendering: auto; background: white; padding: 16px; border-radius: 10px; box-shadow: 0 3px 12px rgba(0,0,0,.08); }}
</style>
<h1>One More Cap Icon Drafts</h1>
<h1>Icon Composer App Icon Drafts</h1>
{''.join(rows)}
<h1>Menu Bar Template Drafts</h1>
{''.join(menu_items)}
</html>
"""
    (ROOT / "index.html").write_text(html, encoding="utf-8")


def make_contact_sheet() -> None:
    subprocess.run(
        ["swift", str(ROOT / "make_contact_sheet.swift"), str(ROOT)],
        check=True,
    )


def main() -> None:
    for child in ["icon-composer", "menu-bar", "previews"]:
        path = ROOT / child
        if path.exists():
            shutil.rmtree(path)
    icon_dirs = [make_icon_bundle(variant) for variant in VARIANTS]
    make_menu_assets()
    for icon_dir in icon_dirs:
        export_icon_previews(icon_dir)
    make_index(icon_dirs)
    make_contact_sheet()


if __name__ == "__main__":
    main()
