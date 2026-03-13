#!/usr/bin/env python3

import json
import math
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path


GEOJSON_URL = "https://raw.githubusercontent.com/johan/world.geo.json/master/countries/AUS.geo.json"
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "RediM8" / "Resources" / "Assets.xcassets"
APP_ICON = ASSETS / "AppIcon.appiconset"
BRAND_MARK = ASSETS / "brand_mark.imageset"
OUTPUT_BASE = ROOT / "tools" / "generated-brand"


def polygon_area(points):
    area = 0.0
    for index, (x1, y1) in enumerate(points):
        x2, y2 = points[(index + 1) % len(points)]
        area += x1 * y2 - x2 * y1
    return abs(area) / 2.0


def perpendicular_distance(point, start, end):
    if start == end:
        return math.dist(point, start)

    x0, y0 = point
    x1, y1 = start
    x2, y2 = end
    numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
    denominator = math.hypot(y2 - y1, x2 - x1)
    return numerator / denominator


def simplify(points, tolerance):
    if len(points) < 3:
        return points

    max_distance = 0.0
    split_index = 0
    start = points[0]
    end = points[-1]

    for index in range(1, len(points) - 1):
        distance = perpendicular_distance(points[index], start, end)
        if distance > max_distance:
            max_distance = distance
            split_index = index

    if max_distance > tolerance:
        first = simplify(points[: split_index + 1], tolerance)
        second = simplify(points[split_index:], tolerance)
        return first[:-1] + second

    return [start, end]


def fetch_outline():
    with urllib.request.urlopen(GEOJSON_URL, timeout=20) as response:
        payload = json.load(response)

    coordinates = payload["features"][0]["geometry"]["coordinates"]
    polygons = []
    for polygon in coordinates:
        ring = polygon[0]
        polygons.append([(lon, lat) for lon, lat in ring])

    polygons.sort(key=polygon_area, reverse=True)
    return polygons[0], polygons[1]


def transform(points, frame):
    min_x, min_y, max_x, max_y = frame
    width = max_x - min_x
    height = max_y - min_y
    max_dimension = max(width, height)

    transformed = []
    for x, y in points:
        normalized_x = (x - min_x) / max_dimension
        normalized_y = (max_y - y) / max_dimension
        transformed.append((normalized_x, normalized_y))
    return transformed


def scale_and_offset(points, scale, offset_x, offset_y):
    return [(x * scale + offset_x, y * scale + offset_y) for x, y in points]


def path_data(points):
    commands = [f"M {points[0][0]:.2f} {points[0][1]:.2f}"]
    commands.extend(f"L {x:.2f} {y:.2f}" for x, y in points[1:])
    commands.append("Z")
    return " ".join(commands)


def build_svg(mainland_path, tasmania_path):
    circles = [150, 220, 290, 360]
    circle_markup = "\n".join(
        f'<circle cx="512" cy="518" r="{radius}" fill="none" stroke="url(#ringGradient)" stroke-width="{8 if radius == 150 else 5}" opacity="{0.88 if radius == 150 else 0.34}" />'
        for radius in circles
    )

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="outlineGradient" x1="220" y1="690" x2="820" y2="270" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#ff4d43" />
      <stop offset="0.52" stop-color="#ff6b3d" />
      <stop offset="1" stop-color="#ffb14d" />
    </linearGradient>
    <linearGradient id="ringGradient" x1="250" y1="770" x2="790" y2="250" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#ff4136" />
      <stop offset="1" stop-color="#ff8b42" />
    </linearGradient>
    <radialGradient id="coreGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="#40130d" stop-opacity="0.8" />
      <stop offset="0.55" stop-color="#1c0c0a" stop-opacity="0.36" />
      <stop offset="1" stop-color="#050505" stop-opacity="0" />
    </radialGradient>
    <filter id="softGlow" x="0" y="0" width="1024" height="1024" filterUnits="userSpaceOnUse">
      <feGaussianBlur stdDeviation="14" />
    </filter>
    <filter id="strongGlow" x="0" y="0" width="1024" height="1024" filterUnits="userSpaceOnUse">
      <feGaussianBlur stdDeviation="28" />
    </filter>
  </defs>

  <rect width="1024" height="1024" fill="#050505" />
  <rect width="1024" height="1024" fill="url(#coreGlow)" />

  <g filter="url(#softGlow)">
    {circle_markup}
  </g>

  <g opacity="0.96">
    {circle_markup}
  </g>

  <circle cx="512" cy="518" r="98" fill="#080808" />
  <circle cx="512" cy="518" r="106" fill="none" stroke="url(#ringGradient)" stroke-width="6" opacity="0.95" />

  <g fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="{mainland_path}" stroke="#ff3d33" stroke-width="22" opacity="0.24" filter="url(#strongGlow)" />
    <path d="{tasmania_path}" stroke="#ff3d33" stroke-width="20" opacity="0.22" filter="url(#strongGlow)" />
    <path d="{mainland_path}" stroke="#ff5f3e" stroke-width="11" opacity="0.46" filter="url(#softGlow)" />
    <path d="{tasmania_path}" stroke="#ff5f3e" stroke-width="10" opacity="0.42" filter="url(#softGlow)" />
    <path d="{mainland_path}" stroke="url(#outlineGradient)" stroke-width="7" />
    <path d="{tasmania_path}" stroke="url(#outlineGradient)" stroke-width="6" />
  </g>
</svg>
"""


def run(command):
    subprocess.run(command, check=True)


def main():
    mainland, tasmania = fetch_outline()

    all_points = mainland + tasmania
    min_x = min(point[0] for point in all_points)
    max_x = max(point[0] for point in all_points)
    min_y = min(point[1] for point in all_points)
    max_y = max(point[1] for point in all_points)

    mainland_points = transform(mainland, (min_x, min_y, max_x, max_y))
    tasmania_points = transform(tasmania, (min_x, min_y, max_x, max_y))

    mainland_points = scale_and_offset(simplify(mainland_points, 0.006), 620, 180, 232)
    tasmania_points = scale_and_offset(simplify(tasmania_points, 0.004), 620, 180, 232)

    svg = build_svg(path_data(mainland_points), path_data(tasmania_points))

    OUTPUT_BASE.mkdir(parents=True, exist_ok=True)
    svg_path = OUTPUT_BASE / "brand-mark.svg"
    svg_path.write_text(svg)

    with tempfile.TemporaryDirectory() as temp_dir:
        preview_dir = Path(temp_dir)
        run(["qlmanage", "-t", "-s", "1024", "-o", str(preview_dir), str(svg_path)])
        preview_png = preview_dir / f"{svg_path.name}.png"
        if not preview_png.exists():
            print("Failed to create PNG preview from SVG.", file=sys.stderr)
            sys.exit(1)

        master_png = OUTPUT_BASE / "brand-mark-1024.png"
        run(["cp", str(preview_png), str(master_png)])

        icon_sizes = {
            "icon-20@2x.png": 40,
            "icon-20@3x.png": 60,
            "icon-ipad-20@1x.png": 20,
            "icon-ipad-20@2x.png": 40,
            "icon-29@2x.png": 58,
            "icon-29@3x.png": 87,
            "icon-ipad-29@1x.png": 29,
            "icon-ipad-29@2x.png": 58,
            "icon-40@2x.png": 80,
            "icon-40@3x.png": 120,
            "icon-ipad-40@1x.png": 40,
            "icon-ipad-40@2x.png": 80,
            "icon-60@2x.png": 120,
            "icon-60@3x.png": 180,
            "icon-ipad-76@1x.png": 76,
            "icon-ipad-76@2x.png": 152,
            "icon-ipad-83_5@2x.png": 167,
            "icon-1024.png": 1024,
        }

        APP_ICON.mkdir(parents=True, exist_ok=True)
        BRAND_MARK.mkdir(parents=True, exist_ok=True)

        for filename, size in icon_sizes.items():
            output_path = APP_ICON / filename
            run(["sips", "-z", str(size), str(size), str(master_png), "--out", str(output_path)])

        run(["cp", str(master_png), str(BRAND_MARK / "brand-mark.png")])


if __name__ == "__main__":
    main()
