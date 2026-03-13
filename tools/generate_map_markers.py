#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "map_markers"
ASSET_CATALOG_DIR = ROOT / "RediM8" / "Resources" / "Assets.xcassets"

VIEWBOX = "0 0 48 48"
BACKGROUND = "#000000"
PANEL_STROKE = "#3A3A3C"
TEXT_PRIMARY = "#FFFFFF"
TEXT_SECONDARY = "#8E8E93"
PIN_PATH = "M24 43C24 43 12 31.8 12 20.5 12 13.6 17.4 8 24 8s12 5.6 12 12.5C36 31.8 24 43 24 43Z"

PALETTE = {
    "safe": "#32D74B",
    "water": "#0A84FF",
    "emergency": "#FF453A",
    "warning": "#FFD60A",
    "neutral": "#64D2FF",
}

MARKER_SPECS = [
    ("shelter_marker", "Shelter", "shelter", "safe"),
    ("medical_marker", "Medical", "medical", "emergency"),
    ("first_aid_marker", "First Aid", "first_aid", "emergency"),
    ("hospital_marker", "Hospital", "hospital", "emergency"),
    ("police_marker", "Police", "police", "neutral"),
    ("warning_marker", "Warning", "warning", "warning"),
    ("water_marker", "Water", "water", "water"),
    ("fuel_marker", "Fuel", "fuel", "warning"),
    ("food_marker", "Food", "food", "safe"),
    ("pharmacy_marker", "Pharmacy", "pharmacy", "emergency"),
    ("hardware_store_marker", "Hardware", "hardware_store", "neutral"),
    ("dirt_road_marker", "Dirt Road", "dirt_road", "neutral"),
    ("fire_trail_marker", "Fire Trail", "fire_trail", "warning"),
    ("route_marker", "Route", "route", "neutral"),
    ("checkpoint_marker", "Checkpoint", "checkpoint", "neutral"),
    ("airstrip_marker", "Airstrip", "airstrip", "neutral"),
    ("campground_marker", "Campground", "campground", "safe"),
    ("fourwd_track_marker", "4WD Track", "fourwd_track", "warning"),
    ("remote_water_marker", "Remote Water", "remote_water", "water"),
    ("outback_supply_marker", "Outback Supply", "outback_supply", "safe"),
    ("community_beacon_marker", "Community Beacon", "community_beacon", "safe"),
    ("signal_node_marker", "Signal Node", "signal_node", "safe"),
    ("radio_marker", "Radio", "radio", "neutral"),
]

LAYER_SPECS = [
    ("layer_water", "Water Layer", "water", "water"),
    ("layer_fire_trails", "Fire Trails", "fire_trail", "warning"),
    ("layer_roads", "Roads", "dirt_road", "neutral"),
    ("layer_shelters", "Shelters", "shelter", "safe"),
    ("layer_beacons", "Beacons", "community_beacon", "safe"),
    ("layer_airstrips", "Airstrips", "airstrip", "neutral"),
]

LEGEND_ITEMS = [
    ("Shelter", "shelter", "safe"),
    ("Water", "water", "water"),
    ("Fuel", "fuel", "warning"),
    ("Medical", "medical", "emergency"),
    ("Fire Trail", "fire_trail", "warning"),
    ("Airstrip", "airstrip", "neutral"),
    ("Beacon", "community_beacon", "safe"),
]

ICON_LAYOUT_OVERRIDES = {
    "first_aid": {"scale": 0.72, "dy": 0.9},
    "food": {"scale": 0.76, "dy": 0.7},
    "fuel": {"scale": 0.76, "dy": 0.8},
    "hardware_store": {"scale": 0.72, "dy": 0.8},
    "airstrip": {"scale": 0.74, "dy": 0.9},
    "campground": {"scale": 0.78, "dy": 0.7},
    "fourwd_track": {"scale": 0.7, "dy": 0.8},
    "remote_water": {"scale": 0.76, "dy": 0.6},
    "outback_supply": {"scale": 0.74, "dy": 0.8},
    "community_beacon": {"scale": 0.72, "dy": 0.7},
    "radio": {"scale": 0.72, "dy": 1.0},
}


def attrs(**values: object) -> str:
    rendered = []
    for key, value in values.items():
        if value is None:
            continue
        rendered.append(f'{key.replace("_", "-")}="{value}"')
    return " ".join(rendered)


def element(tag: str, **values: object) -> str:
    return f"<{tag} {attrs(**values)}/>"


def wrap(tag: str, content: str, **values: object) -> str:
    return f"<{tag} {attrs(**values)}>{content}</{tag}>"


def path(d: str, **values: object) -> str:
    return element("path", d=d, **values)


def line(x1: float, y1: float, x2: float, y2: float, **values: object) -> str:
    return element("line", x1=x1, y1=y1, x2=x2, y2=y2, **values)


def circle(cx: float, cy: float, r: float, **values: object) -> str:
    return element("circle", cx=cx, cy=cy, r=r, **values)


def rect(x: float, y: float, width: float, height: float, rx: float | None = None, ry: float | None = None, **values: object) -> str:
    return element("rect", x=x, y=y, width=width, height=height, rx=rx, ry=ry, **values)


def polyline(points: Iterable[tuple[float, float]], **values: object) -> str:
    return element("polyline", points=" ".join(f"{x},{y}" for x, y in points), **values)


def polygon(points: Iterable[tuple[float, float]], **values: object) -> str:
    return element("polygon", points=" ".join(f"{x},{y}" for x, y in points), **values)


def text(content: str, **values: object) -> str:
    return wrap("text", content, **values)


def group(children: list[str], **values: object) -> str:
    return wrap("g", "".join(children), **values)


def svg_document(children: list[str], viewbox: str, width: int | None = None, height: int | None = None) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{viewbox}"'
        + (f' width="{width}"' if width is not None else "")
        + (f' height="{height}"' if height is not None else "")
        + ">"
        + "".join(children)
        + "</svg>"
    )


def base_icons() -> dict[str, list[str]]:
    return {
        "shelter": [
            polyline([(4, 11), (12, 5), (20, 11)]),
            path("M6 10.5V19h12v-8.5"),
            path("M10 19v-4h4v4"),
        ],
        "medical": [
            circle(12, 12, 7),
            line(12, 8.5, 12, 15.5),
            line(8.5, 12, 15.5, 12),
        ],
        "first_aid": [
            path("M9 8V6.5a3 3 0 0 1 6 0V8"),
            rect(4, 8, 16, 11, rx=2.5),
            line(12, 10.8, 12, 16.2),
            line(9.3, 13.5, 14.7, 13.5),
        ],
        "hospital": [
            rect(5.5, 5.5, 13, 13, rx=2.2),
            line(8.5, 8.2, 8.5, 15.8),
            line(15.5, 8.2, 15.5, 15.8),
            line(8.5, 12, 15.5, 12),
        ],
        "police": [
            path("M12 4.5l6 2.4v4.1c0 4-2.5 6.9-6 8.9-3.5-2-6-4.9-6-8.9V6.9z"),
            line(12, 8.5, 12, 13.5),
            line(9.5, 11, 14.5, 11),
        ],
        "warning": [
            polygon([(12, 4), (20, 19), (4, 19)]),
            line(12, 9, 12, 13.5),
            circle(12, 16.8, 0.9),
        ],
        "water": [
            path("M12 4C9 8 7 10.5 7 14a5 5 0 0 0 10 0c0-3.5-2-6-5-10z"),
            path("M9.5 14c1 .8 4 .8 5 0"),
        ],
        "fuel": [
            rect(6.5, 6, 7.5, 12, rx=1.6),
            line(8.5, 9, 12, 9),
            line(8.5, 12, 12, 12),
            path("M14 8h2l2 2.5V17"),
            path("M16.5 12.5h1.5"),
        ],
        "food": [
            path("M7 7c0-1.1 2.2-2 5-2s5 .9 5 2v10c0 1.1-2.2 2-5 2s-5-.9-5-2z"),
            path("M7 7c0 1.1 2.2 2 5 2s5-.9 5-2"),
            path("M7 17c0 1.1 2.2 2 5 2s5-.9 5-2"),
        ],
        "pharmacy": [
            rect(4, 8, 16, 8, rx=4),
            line(12, 8, 12, 16),
            line(7.2, 10.8, 10, 13.6),
        ],
        "hardware_store": [
            circle(16.8, 7.5, 2.1),
            path("M15.4 8.9l-8.7 8.7"),
            line(6.7, 17.6, 8.9, 19.8),
            path("M10 8l2.2 2.2"),
            line(8.5, 9.5, 12.5, 5.5),
        ],
        "dirt_road": [
            path("M8 20L10.5 4"),
            path("M16 20L13.5 4"),
            line(12, 6, 12, 8),
            line(12, 10, 12, 12),
            line(12, 14, 12, 16),
            line(12, 18, 12, 19),
        ],
        "fire_trail": [
            path("M8 20l2.2-8"),
            path("M16 20l-2.2-8"),
            path("M12 4c1.5 2 3 3.2 3 5a3 3 0 0 1-6 0c0-1.8 1.1-3.2 3-5z"),
            line(12, 12, 12, 18),
        ],
        "route": [
            circle(6, 18, 1.4),
            circle(18, 6, 1.4),
            path("M7.5 18C11.5 18 9.5 10 14 10h2.5"),
            polyline([(16.5, 8), (18.5, 6), (16.5, 4)]),
        ],
        "checkpoint": [
            line(7, 5.5, 7, 19),
            path("M7 7h9l-2.7 3 2.7 3H7"),
            line(5, 19, 19, 19),
        ],
        "airstrip": [
            polygon([(8, 4), (16, 4), (18, 20), (6, 20)]),
            line(12, 7, 12, 9),
            line(12, 11, 12, 13),
            line(12, 15, 12, 17),
        ],
        "campground": [
            polygon([(4, 19), (12, 5), (20, 19)]),
            line(12, 5, 12, 19),
            polyline([(9, 19), (12, 14), (15, 19)]),
        ],
        "fourwd_track": [
            path("M4 14l2.5-4h9l4 4v4H4z"),
            circle(8, 18, 2.5),
            circle(17, 18, 2.5),
            line(9, 10, 14, 10),
            polyline([(8, 8), (9, 6), (15, 6), (16, 8)]),
        ],
        "remote_water": [
            path("M12 4.5c-2.7 3.7-4.3 5.9-4.3 8.7a4.3 4.3 0 0 0 8.6 0c0-2.8-1.6-5-4.3-8.7z"),
            line(6, 18.2, 18, 18.2),
            line(8.5, 20, 15.5, 20),
        ],
        "outback_supply": [
            path("M6 10l2.2-4h7.6l2.2 4"),
            rect(5, 10, 14, 9, rx=1.8),
            line(12, 10, 12, 19),
            line(5, 14.5, 19, 14.5),
        ],
        "community_beacon": [
            circle(12, 11.5, 1.5),
            path("M9 9a4 4 0 0 0 0 5"),
            path("M15 9a4 4 0 0 1 0 5"),
            path("M7 6a7 7 0 0 0 0 11"),
            path("M17 6a7 7 0 0 1 0 11"),
            line(12, 13.5, 12, 18.5),
            line(8, 19, 16, 19),
        ],
        "signal_node": [
            circle(12, 12, 1.5),
            path("M7.5 12a4.5 4.5 0 0 1 9 0"),
            path("M7.5 12a4.5 4.5 0 0 0 9 0"),
            line(5, 12, 6.2, 12),
            line(17.8, 12, 19, 12),
        ],
        "radio": [
            rect(7, 7, 10, 13, rx=2),
            line(10, 7, 8, 3.5),
            line(10, 11, 14, 11),
            line(10, 14, 14, 14),
            circle(13.5, 17.3, 1.5),
            line(9, 18.8, 9.8, 18.8),
        ],
    }


def icon_transform(icon_name: str, target_center_y: float) -> str:
    override = ICON_LAYOUT_OVERRIDES.get(icon_name, {})
    scale = override.get("scale", 0.78)
    dx = override.get("dx", 0.0)
    dy = override.get("dy", 0.0)
    x = 24 - 12 * scale + dx
    y = target_center_y - 12 * scale + dy
    return f"translate({x:.3f} {y:.3f}) scale({scale:.3f})"


def marker_shapes(icon_name: str, stroke: str, icon_map: dict[str, list[str]]) -> list[str]:
    return [
        path(PIN_PATH),
        group(icon_map[icon_name], transform=icon_transform(icon_name, target_center_y=19), fill="none"),
    ]


def overlay_shapes(icon_name: str, stroke: str, icon_map: dict[str, list[str]]) -> list[str]:
    return [
        circle(24, 24, 18),
        group(icon_map[icon_name], transform=icon_transform(icon_name, target_center_y=24), fill="none"),
    ]


def marker_svg(icon_name: str, stroke: str, icon_map: dict[str, list[str]]) -> str:
    return svg_document(
        [
            group(
                marker_shapes(icon_name, stroke, icon_map),
                fill="none",
                stroke=stroke,
                stroke_width=2,
                stroke_linecap="round",
                stroke_linejoin="round",
            )
        ],
        VIEWBOX,
        width=48,
        height=48,
    )


def overlay_svg(icon_name: str, stroke: str, icon_map: dict[str, list[str]]) -> str:
    return svg_document(
        [
            group(
                overlay_shapes(icon_name, stroke, icon_map),
                fill="none",
                stroke=stroke,
                stroke_width=2,
                stroke_linecap="round",
                stroke_linejoin="round",
            )
        ],
        VIEWBOX,
        width=48,
        height=48,
    )


def preview_background(width: int, height: int) -> list[str]:
    parts = [
        rect(0, 0, width, height, fill=BACKGROUND),
    ]

    for x in range(32, width, 96):
        parts.append(line(x, 0, x, height, stroke="#1F1F22", stroke_width=1))
    for y in range(88, height, 96):
        parts.append(line(0, y, width, y, stroke="#1F1F22", stroke_width=1))

    return parts


def preview_marker_cell(x: int, y: int, label: str, icon_name: str, stroke: str, icon_map: dict[str, list[str]]) -> list[str]:
    size = 128
    return [
        rect(x, y, size, 112, rx=22, fill="none", stroke=PANEL_STROKE, stroke_width=1),
        group(
            marker_shapes(icon_name, stroke, icon_map),
            transform=f"translate({x + 40} {y + 12})",
            fill="none",
            stroke=stroke,
            stroke_width=2,
            stroke_linecap="round",
            stroke_linejoin="round",
        ),
        text(
            label,
            x=x + size / 2,
            y=y + 95,
            fill=TEXT_PRIMARY,
            font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
            font_size=12,
            font_weight=600,
            text_anchor="middle",
        ),
    ]


def preview_layer_cell(x: int, y: int, label: str, icon_name: str, stroke: str, icon_map: dict[str, list[str]]) -> list[str]:
    return [
        rect(x, y, 128, 96, rx=22, fill="none", stroke=PANEL_STROKE, stroke_width=1),
        group(
            overlay_shapes(icon_name, stroke, icon_map),
            transform=f"translate({x + 40} {y + 12})",
            fill="none",
            stroke=stroke,
            stroke_width=2,
            stroke_linecap="round",
            stroke_linejoin="round",
        ),
        text(
            label,
            x=x + 64,
            y=y + 80,
            fill=TEXT_SECONDARY,
            font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
            font_size=11,
            font_weight=500,
            text_anchor="middle",
        ),
    ]


def generate_preview_sheet(icon_map: dict[str, list[str]]) -> str:
    columns = 5
    cell_width = 140
    margin = 32
    marker_rows = math.ceil(len(MARKER_SPECS) / columns)
    width = margin * 2 + columns * cell_width
    marker_section_height = marker_rows * 124
    layer_section_y = 118 + marker_section_height + 48
    height = layer_section_y + 148 + 32

    parts = preview_background(width, height)
    parts.extend(
        [
            text(
                "RediM8 Map Marker System",
                x=margin,
                y=44,
                fill=TEXT_PRIMARY,
                font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
                font_size=28,
                font_weight=700,
            ),
            text(
                "48x48 tactical pins for dark offline maps, plus layer overlays and fixed emergency color roles.",
                x=margin,
                y=68,
                fill=TEXT_SECONDARY,
                font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
                font_size=14,
            ),
        ]
    )

    swatch_x = width - margin - 290
    swatches = [
        ("Safe", PALETTE["safe"]),
        ("Water", PALETTE["water"]),
        ("Emergency", PALETTE["emergency"]),
        ("Warning", PALETTE["warning"]),
        ("Info", PALETTE["neutral"]),
    ]
    for index, (label, color) in enumerate(swatches):
        x = swatch_x + index * 58
        parts.append(circle(x, 44, 7, fill=color, stroke="none"))
        parts.append(
            text(
                label[0],
                x=x,
                y=49,
                fill=BACKGROUND,
                font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
                font_size=10,
                font_weight=700,
                text_anchor="middle",
            )
        )

    origin_y = 96
    for index, (_, label, icon_name, color_key) in enumerate(MARKER_SPECS):
        col = index % columns
        row = index // columns
        x = margin + col * cell_width
        y = origin_y + row * 124
        parts.extend(preview_marker_cell(x, y, label, icon_name, PALETTE[color_key], icon_map))

    parts.extend(
        [
            text(
                "Layer Overlays",
                x=margin,
                y=layer_section_y,
                fill=TEXT_PRIMARY,
                font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
                font_size=20,
                font_weight=650,
            ),
            text(
                "Circular overlays for map layer toggles, legend chips, and map help surfaces.",
                x=margin,
                y=layer_section_y + 20,
                fill=TEXT_SECONDARY,
                font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
                font_size=13,
            ),
        ]
    )

    layer_y = layer_section_y + 36
    for index, (_, label, icon_name, color_key) in enumerate(LAYER_SPECS):
        x = margin + index * 114
        parts.extend(preview_layer_cell(x, layer_y, label, icon_name, PALETTE[color_key], icon_map))

    return svg_document(parts, f"0 0 {width} {height}", width=width, height=height)


def legend_entry(x: int, y: int, label: str, icon_name: str, color_key: str, icon_map: dict[str, list[str]]) -> list[str]:
    stroke = PALETTE[color_key]
    return [
        group(
            marker_shapes(icon_name, stroke, icon_map),
            transform=f"translate({x} {y}) scale(0.95)",
            fill="none",
            stroke=stroke,
            stroke_width=2,
            stroke_linecap="round",
            stroke_linejoin="round",
        ),
        text(
            label,
            x=x + 64,
            y=y + 34,
            fill=TEXT_PRIMARY,
            font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
            font_size=16,
            font_weight=600,
        ),
    ]


def generate_legend(icon_map: dict[str, list[str]]) -> str:
    width = 760
    height = 430
    parts = [
        rect(0, 0, width, height, rx=28, fill=BACKGROUND),
        rect(1, 1, width - 2, height - 2, rx=27, fill="none", stroke=PANEL_STROKE, stroke_width=2),
        text(
            "Map Legend",
            x=36,
            y=48,
            fill=TEXT_PRIMARY,
            font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
            font_size=28,
            font_weight=700,
        ),
        text(
            "Emergency navigation markers tuned for dark maps and fast recognition.",
            x=36,
            y=72,
            fill=TEXT_SECONDARY,
            font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
            font_size=14,
        ),
    ]

    note_y = 106
    note_items = [
        ("Safe resources", PALETTE["safe"]),
        ("Water", PALETTE["water"]),
        ("Emergency", PALETTE["emergency"]),
        ("Warnings", PALETTE["warning"]),
        ("Information", PALETTE["neutral"]),
    ]
    for index, (label, color) in enumerate(note_items):
        x = 36 + index * 138
        parts.append(circle(x, note_y - 4, 5, fill=color, stroke="none"))
        parts.append(
            text(
                label,
                x=x + 12,
                y=note_y,
                fill=TEXT_SECONDARY,
                font_family="SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif",
                font_size=12,
            )
        )

    start_y = 138
    row_gap = 78
    col_x = [36, 390]
    for index, (label, icon_name, color_key) in enumerate(LEGEND_ITEMS):
        col = index % 2
        row = index // 2
        parts.extend(legend_entry(col_x[col], start_y + row * row_gap, label, icon_name, color_key, icon_map))

    return svg_document(parts, f"0 0 {width} {height}", width=width, height=height)


def render_png(svg_path: Path) -> None:
    sips = shutil.which("sips")
    if not sips:
        return

    subprocess.run(
        [sips, "-s", "format", "png", str(svg_path), "--out", str(svg_path.with_suffix(".png"))],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def sync_asset_catalog(svg_paths: list[Path]) -> None:
    for svg_path in svg_paths:
        image_set_dir = ASSET_CATALOG_DIR / f"{svg_path.stem}.imageset"
        image_set_dir.mkdir(parents=True, exist_ok=True)
        pdf_path = image_set_dir / f"{svg_path.stem}.pdf"

        subprocess.run(
            ["sips", "-s", "format", "pdf", str(svg_path), "--out", str(pdf_path)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        contents = {
            "images": [
                {
                    "filename": pdf_path.name,
                    "idiom": "universal",
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1,
            },
            "properties": {
                "preserves-vector-representation": True,
                "template-rendering-intent": "original",
            },
        }
        (image_set_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def write_svg(path: Path, content: str) -> None:
    path.write_text(content + "\n", encoding="utf-8")


def write_files(sync_assets: bool) -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)
    icon_map = base_icons()
    generated_svgs: list[Path] = []

    for filename, _, icon_name, color_key in MARKER_SPECS:
        svg_path = OUTPUT_DIR / f"{filename}.svg"
        write_svg(svg_path, marker_svg(icon_name, PALETTE[color_key], icon_map))
        generated_svgs.append(svg_path)

    for filename, _, icon_name, color_key in LAYER_SPECS:
        svg_path = OUTPUT_DIR / f"{filename}.svg"
        write_svg(svg_path, overlay_svg(icon_name, PALETTE[color_key], icon_map))
        generated_svgs.append(svg_path)

    preview_path = OUTPUT_DIR / "marker_preview_sheet.svg"
    legend_path = OUTPUT_DIR / "map_legend.svg"
    write_svg(preview_path, generate_preview_sheet(icon_map))
    write_svg(legend_path, generate_legend(icon_map))

    render_png(preview_path)
    render_png(legend_path)

    if sync_assets:
        sync_asset_catalog(generated_svgs + [legend_path])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate RediM8 tactical map marker SVG assets.")
    parser.add_argument(
        "--sync-asset-catalog",
        action="store_true",
        help="Convert generated SVGs to vector PDFs and write matching image sets into Assets.xcassets.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    write_files(sync_assets=args.sync_asset_catalog)
