#!/bin/bash
#
# Build .osrg routing graphs for all Australian region packs.
#
# Prerequisites:
#   1. pip install osmium shapely
#   2. Download australia-latest.osm.pbf from Geofabrik:
#      wget https://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf
#
# Usage:
#   ./build_australia_packs.sh [path/to/australia-latest.osm.pbf] [output_dir]
#
# Output:
#   output_dir/brisbane-routing.osrg     (~60-80MB)
#   output_dir/qld-routing.osrg          (~150-200MB)
#   output_dir/nsw-routing.osrg          (~150-200MB)
#   output_dir/vic-routing.osrg          (~100-150MB)
#   output_dir/sa-routing.osrg           (~80-120MB)
#   output_dir/wa-routing.osrg           (~80-120MB)
#   output_dir/nt-routing.osrg           (~40-80MB)
#   output_dir/tas-routing.osrg          (~30-50MB)
#   output_dir/act-routing.osrg          (~10-20MB)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PBF="${1:-australia-latest.osm.pbf}"
OUTPUT_DIR="${2:-./osrg-output}"

if [ ! -f "$PBF" ]; then
    echo "ERROR: OSM PBF file not found: $PBF"
    echo "Download from: https://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo "  OSRG Pack Builder — Australia"
echo "  Input: $PBF"
echo "  Output: $OUTPUT_DIR"
echo "============================================"
echo

# Region definitions: name, bbox (min_lat,min_lon,max_lat,max_lon)
declare -A REGIONS
REGIONS=(
    ["brisbane"]="-28.2,152.5,-27.0,153.6"
    ["qld"]="-29.2,138.0,-10.0,154.0"
    ["nsw"]="-37.6,141.0,-28.2,153.7"
    ["vic"]="-39.2,141.0,-34.0,150.2"
    ["sa"]="-38.1,129.0,-26.0,141.0"
    ["wa"]="-35.2,112.9,-13.7,129.0"
    ["nt"]="-26.0,129.0,-10.9,138.0"
    ["tas"]="-43.7,144.5,-39.5,148.5"
    ["act"]="-35.95,148.75,-35.1,149.4"
)

TOTAL=${#REGIONS[@]}
CURRENT=0

for region in "${!REGIONS[@]}"; do
    CURRENT=$((CURRENT + 1))
    BBOX="${REGIONS[$region]}"
    OUTPUT="$OUTPUT_DIR/${region}-routing.osrg"

    echo "[$CURRENT/$TOTAL] Building $region ($BBOX)..."
    python3 "$SCRIPT_DIR/build_osrg.py" \
        --input "$PBF" \
        --region "$region" \
        --bbox "$BBOX" \
        --output "$OUTPUT" \
        --version "1.0"
    echo
done

echo "============================================"
echo "  All packs built successfully!"
echo "============================================"
echo
echo "Output files:"
ls -lh "$OUTPUT_DIR"/*.osrg 2>/dev/null || echo "  (none)"
echo
echo "Total size:"
du -sh "$OUTPUT_DIR" 2>/dev/null
