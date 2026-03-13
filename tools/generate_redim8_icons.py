#!/usr/bin/env python3

from __future__ import annotations

import math
import os
import json
import shutil
import subprocess
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "icons"
ASSET_CATALOG_DIR = ROOT / "RediM8" / "Resources" / "Assets.xcassets"
STROKE = "#00FF8A"
CELL_STROKE = "#0A3821"
LABEL_COLOR = "#77E5B1"
BACKGROUND = "#000000"
VIEWBOX = "0 0 24 24"


def attrs(**values: object) -> str:
    rendered = []
    for key, value in values.items():
        if value is None:
            continue
        rendered.append(f'{key.replace("_", "-")}="{value}"')
    return " ".join(rendered)


def element(tag: str, **values: object) -> str:
    return f"<{tag} {attrs(**values)}/>"


def path(d: str) -> str:
    return element("path", d=d)


def line(x1: float, y1: float, x2: float, y2: float) -> str:
    return element("line", x1=x1, y1=y1, x2=x2, y2=y2)


def circle(cx: float, cy: float, r: float) -> str:
    return element("circle", cx=cx, cy=cy, r=r)


def rect(x: float, y: float, width: float, height: float, rx: float | None = None, ry: float | None = None) -> str:
    return element("rect", x=x, y=y, width=width, height=height, rx=rx, ry=ry)


def polyline(points: Iterable[tuple[float, float]]) -> str:
    return element("polyline", points=" ".join(f"{x},{y}" for x, y in points))


def polygon(points: Iterable[tuple[float, float]]) -> str:
    return element("polygon", points=" ".join(f"{x},{y}" for x, y in points))


def text(content: str, **values: object) -> str:
    return f"<text {attrs(**values)}>{content}</text>"


def icon_svg(elements: list[str]) -> str:
    body = "".join(elements)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}" '
        f'fill="none" stroke="{STROKE}" stroke-width="2" '
        'stroke-linecap="round" stroke-linejoin="round">'
        f"{body}</svg>"
    )


ICON_ORDER = [
    "emergency",
    "warning",
    "alert",
    "beacon",
    "radio",
    "signal",
    "go_bag",
    "first_aid",
    "documents",
    "battery",
    "flashlight",
    "power_bank",
    "water",
    "shelter",
    "fuel",
    "medical",
    "pharmacy",
    "food",
    "compass",
    "map_marker",
    "route",
    "dirt_road",
    "fire_trail",
    "airstrip",
    "vehicle",
    "four_wd",
    "tent",
    "camp",
    "fire_extinguisher",
    "fire_blanket",
    "rope",
    "whistle",
    "knife",
    "pet",
    "dog",
    "livestock",
    "family",
    "meeting_point",
]


PRETTY_LABELS = {
    "go_bag": "GO BAG",
    "first_aid": "FIRST AID",
    "power_bank": "POWER BANK",
    "map_marker": "MAP MARKER",
    "dirt_road": "DIRT ROAD",
    "fire_trail": "FIRE TRAIL",
    "four_wd": "4WD",
    "fire_extinguisher": "EXTINGUISHER",
    "fire_blanket": "BLANKET",
    "meeting_point": "MEETING",
}


def icons() -> dict[str, list[str]]:
    return {
        "emergency": [
            polygon([(8.5, 3.5), (15.5, 3.5), (20.5, 8.5), (20.5, 15.5), (15.5, 20.5), (8.5, 20.5), (3.5, 15.5), (3.5, 8.5)]),
            line(12, 8, 12, 16),
            line(8, 12, 16, 12),
        ],
        "warning": [
            polygon([(12, 4), (20, 19), (4, 19)]),
            line(12, 9, 12, 13.5),
            circle(12, 16.8, 0.9),
        ],
        "alert": [
            path("M8 15v-4a4 4 0 0 1 8 0v4"),
            line(7, 15, 17, 15),
            line(6, 19, 18, 19),
            line(12, 3, 12, 5),
            line(5, 8, 7, 9.5),
            line(19, 8, 17, 9.5),
        ],
        "beacon": [
            circle(12, 11.5, 1.5),
            path("M9 9a4 4 0 0 0 0 5"),
            path("M15 9a4 4 0 0 1 0 5"),
            path("M7 6a7 7 0 0 0 0 11"),
            path("M17 6a7 7 0 0 1 0 11"),
            line(12, 13.5, 12, 18.5),
            line(8, 19, 16, 19),
        ],
        "radio": [
            rect(7, 7, 10, 13, rx=2),
            line(10, 7, 8, 3.5),
            line(10, 11, 14, 11),
            line(10, 14, 14, 14),
            circle(13.5, 17.3, 1.5),
            line(9, 18.8, 9.8, 18.8),
        ],
        "signal": [
            line(5, 19, 5, 17),
            line(9, 19, 9, 14),
            line(13, 19, 13, 10),
            line(17, 19, 17, 6),
        ],
        "go_bag": [
            path("M9 8V7a3 3 0 0 1 6 0v1"),
            rect(5, 8, 14, 12, rx=3),
            rect(9, 13, 6, 4.5, rx=1.2),
            line(8, 11, 16, 11),
        ],
        "first_aid": [
            path("M9 8V6.5a3 3 0 0 1 6 0V8"),
            rect(4, 8, 16, 11, rx=2.5),
            line(12, 10.8, 12, 16.2),
            line(9.3, 13.5, 14.7, 13.5),
        ],
        "documents": [
            path("M6 7h7l3 3v8H6z"),
            path("M13 7v3h3"),
            path("M9 4h7l3 3v11H9z"),
            path("M16 4v3h3"),
        ],
        "battery": [
            rect(3.5, 8, 15, 8, rx=2),
            rect(18.5, 10, 2, 4, rx=0.7),
            path("M10 10.5l-1 2.2h2l-1 2.8 4-4.8h-2l1-2.2z"),
        ],
        "flashlight": [
            rect(4, 9, 7, 6, rx=2),
            path("M11 8l4 2v4l-4 2"),
            line(16, 9.5, 19, 7.5),
            line(16, 12, 20, 12),
            line(16, 14.5, 19, 16.5),
            line(4, 12, 2.5, 12),
        ],
        "power_bank": [
            rect(8, 4, 8, 16, rx=2),
            line(11, 7, 13, 7),
            path("M10.5 10.5l-1 2.3h2l-1 2.7 4-4.8h-2l1-2.2z"),
            line(11, 20, 11, 22),
            line(13, 20, 13, 22),
        ],
        "water": [
            path("M12 4C9 8 7 10.5 7 14a5 5 0 0 0 10 0c0-3.5-2-6-5-10z"),
            path("M9.5 14c1 .8 4 .8 5 0"),
        ],
        "shelter": [
            polyline([(4, 11), (12, 5), (20, 11)]),
            path("M6 10.5V19h12v-8.5"),
            path("M10 19v-4h4v4"),
        ],
        "fuel": [
            path("M8 5h5l3 3v11H8z"),
            path("M13 5v3h3"),
            line(10, 8, 12, 8),
            line(10, 12, 14, 16),
            line(14, 12, 10, 16),
        ],
        "medical": [
            circle(12, 12, 8),
            line(12, 8.5, 12, 15.5),
            line(8.5, 12, 15.5, 12),
        ],
        "pharmacy": [
            rect(4, 8, 16, 8, rx=4),
            line(12, 8, 12, 16),
            line(7.2, 10.8, 10, 13.6),
        ],
        "food": [
            path("M7 7c0-1.1 2.2-2 5-2s5 .9 5 2v10c0 1.1-2.2 2-5 2s-5-.9-5-2z"),
            path("M7 7c0 1.1 2.2 2 5 2s5-.9 5-2"),
            path("M7 17c0 1.1 2.2 2 5 2s5-.9 5-2"),
        ],
        "compass": [
            circle(12, 12, 8),
            polygon([(12, 7), (15, 12), (12, 17), (9, 12)]),
            circle(12, 12, 1),
        ],
        "map_marker": [
            path("M12 20s6-5 6-10a6 6 0 1 0-12 0c0 5 6 10 6 10z"),
            circle(12, 10, 2),
        ],
        "route": [
            circle(6, 18, 1.4),
            circle(18, 6, 1.4),
            path("M7.5 18C11.5 18 9.5 10 14 10h2.5"),
            polyline([(16.5, 8), (18.5, 6), (16.5, 4)]),
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
        "airstrip": [
            polygon([(8, 4), (16, 4), (18, 20), (6, 20)]),
            line(12, 7, 12, 9),
            line(12, 11, 12, 13),
            line(12, 15, 12, 17),
        ],
        "vehicle": [
            path("M5 15l2-4h8l3 4v3H5z"),
            circle(8, 18, 2),
            circle(16, 18, 2),
            line(9, 11, 14, 11),
        ],
        "four_wd": [
            path("M4 14l2.5-4h9l4 4v4H4z"),
            circle(8, 18, 2.5),
            circle(17, 18, 2.5),
            line(9, 10, 14, 10),
            polyline([(8, 8), (9, 6), (15, 6), (16, 8)]),
        ],
        "tent": [
            polygon([(4, 19), (12, 5), (20, 19)]),
            line(12, 5, 12, 19),
            polyline([(9, 19), (12, 14), (15, 19)]),
        ],
        "camp": [
            path("M10 9c0-2 1.8-3.3 3-5 .5 1 2 2 2 4a4 4 0 0 1-8 0c0-1.4.8-2.7 2-3.5"),
            line(7, 19, 17, 13),
            line(17, 19, 7, 13),
        ],
        "fire_extinguisher": [
            path("M10.5 5h3"),
            rect(9, 7, 6, 12, rx=1.5),
            polyline([(15, 7), (17, 8.5), (17, 12)]),
            polyline([(17, 12), (19, 13.5), (18, 15)]),
            line(11, 11, 13, 11),
        ],
        "fire_blanket": [
            path("M6 4h8l4 4v12H6z"),
            path("M14 4v4h4"),
            line(9, 11, 15, 17),
            line(15, 11, 9, 17),
        ],
        "rope": [
            circle(12, 12, 6),
            circle(12, 12, 2.5),
            path("M16.2 7.8l2.3-2.3"),
            path("M16 16l3 3"),
            path("M19 19l2-1"),
        ],
        "whistle": [
            path("M5 11h6a3 3 0 1 1 0 6H7l-2 2z"),
            circle(13.5, 14, 1.5),
        ],
        "knife": [
            path("M5 18l4-4 6-8 2 2-8 6-4 4z"),
            line(7.5, 16.5, 9.5, 18.5),
        ],
        "pet": [
            circle(7.5, 10.5, 1.2),
            circle(10.5, 8, 1.2),
            circle(13.5, 8, 1.2),
            circle(16.5, 10.5, 1.2),
            path("M8 16c0-2 1.8-4 4-4s4 2 4 4c0 1.7-1.8 3-4 3s-4-1.3-4-3z"),
        ],
        "dog": [
            polyline([(8, 10), (6, 6), (5, 9)]),
            polyline([(16, 10), (18, 6), (19, 9)]),
            path("M7 10v4c0 3.3 2.2 6 5 6s5-2.7 5-6v-4"),
            path("M10 16c1 .8 3 .8 4 0"),
        ],
        "livestock": [
            polyline([(7, 9), (4.5, 6.5), (5.2, 9.2)]),
            polyline([(17, 9), (19.5, 6.5), (18.8, 9.2)]),
            path("M7 9v5c0 3.2 2.2 5.5 5 5.5s5-2.3 5-5.5V9"),
            rect(9, 14, 6, 4, rx=2),
            line(9.5, 18, 8.5, 20),
            line(14.5, 18, 15.5, 20),
        ],
        "family": [
            circle(8, 8.5, 2),
            circle(16, 8.5, 2),
            circle(12, 11.5, 1.6),
            path("M4.5 18c0-2.1 1.6-3.8 3.5-3.8s3.5 1.7 3.5 3.8"),
            path("M12 18c0-2.1 1.8-3.8 4-3.8s4 1.7 4 3.8"),
            path("M9.5 18c0-1.7 1-3 2.5-3s2.5 1.3 2.5 3"),
        ],
        "meeting_point": [
            polyline([(4, 9), (4, 4), (9, 4)]),
            polyline([(20, 9), (20, 4), (15, 4)]),
            polyline([(4, 15), (4, 20), (9, 20)]),
            polyline([(20, 15), (20, 20), (15, 20)]),
            circle(12, 12, 2),
        ],
    }


def generate_preview(icon_map: dict[str, list[str]]) -> str:
    columns = 6
    cell_width = 132
    cell_height = 118
    margin = 24
    header_height = 58
    rows = math.ceil(len(ICON_ORDER) / columns)
    width = margin * 2 + columns * cell_width
    height = header_height + margin + rows * cell_height + margin

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}">',
        element("rect", x=0, y=0, width=width, height=height, fill=BACKGROUND),
        text(
            "RediM8 Emergency Icon Pack",
            x=margin,
            y=36,
            fill=STROKE,
            font_family="SFMono-Regular, Menlo, monospace",
            font_size=22,
        ),
    ]

    for index, name in enumerate(ICON_ORDER):
        col = index % columns
        row = index // columns
        x = margin + col * cell_width
        y = header_height + row * cell_height
        label = PRETTY_LABELS.get(name, name.replace("_", " ").upper())
        icon_x = x + cell_width / 2
        icon_y = y + 24
        label_y = y + 92

        parts.append(
            element(
                "rect",
                x=x,
                y=y,
                width=cell_width - 12,
                height=cell_height - 12,
                rx=16,
                fill="none",
                stroke=CELL_STROKE,
                stroke_width=1,
            )
        )
        parts.append(
            f'<g transform="translate({icon_x - 24},{icon_y}) scale(2)" fill="none" stroke="{STROKE}" '
            'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            + "".join(icon_map[name])
            + "</g>"
        )
        parts.append(
            text(
                label,
                x=icon_x,
                y=label_y,
                fill=LABEL_COLOR,
                font_family="SFMono-Regular, Menlo, monospace",
                font_size=10,
                text_anchor="middle",
                letter_spacing="0.8",
            )
        )

    parts.append("</svg>")
    return "".join(parts)


def write_files() -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)
    icon_map = icons()

    for name in ICON_ORDER:
        svg_path = OUTPUT_DIR / f"{name}.svg"
        svg_path.write_text(icon_svg(icon_map[name]) + "\n", encoding="utf-8")

    preview_svg = OUTPUT_DIR / "preview-grid.svg"
    preview_svg.write_text(generate_preview(icon_map) + "\n", encoding="utf-8")

    render_preview_png(preview_svg)
    sync_asset_catalog()


def render_preview_png(preview_svg: Path) -> None:
    qlmanage = shutil.which("qlmanage")
    if not qlmanage:
        return

    subprocess.run(
        [qlmanage, "-t", "-s", "1800", "-o", str(OUTPUT_DIR), str(preview_svg)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    generated = OUTPUT_DIR / f"{preview_svg.name}.png"
    target = OUTPUT_DIR / "preview-grid.png"
    if generated.exists():
        if target.exists():
            target.unlink()
        os.replace(generated, target)


def sync_asset_catalog() -> None:
    for name in ICON_ORDER:
        svg_path = OUTPUT_DIR / f"{name}.svg"
        image_set_dir = ASSET_CATALOG_DIR / f"{name}.imageset"
        image_set_dir.mkdir(parents=True, exist_ok=True)
        pdf_path = image_set_dir / f"{name}.pdf"

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
                "template-rendering-intent": "template",
            },
        }
        (image_set_dir / "Contents.json").write_text(
            json.dumps(contents, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    write_files()
