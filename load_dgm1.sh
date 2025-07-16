#!/bin/bash

JOBS=6
export OUTPUT_DIR="/bigdata/import/sn/dgm1_sn"
REFERER="https://geocloud.landesvermessung.sachsen.de/index.php/s/rFQV9a4152BOGNL"

mkdir -p "$OUTPUT_DIR"

processDownload() {
    local url="$1"
    local filename
    filename=$(echo "$url" | sed -n 's/.*[?&]files=\([^&]*\).*/\1/p')
    wget --referer="$REFERER" -q --show-progress -O "${OUTPUT_DIR}/${filename}" "$url"
}

export -f processDownload

parallel -j "$JOBS" processDownload :::: urls_All.txt
