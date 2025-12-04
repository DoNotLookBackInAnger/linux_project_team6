#!/usr/local/bin/bash

REPORT_DIR="./reports"
HTML_REPORT="$REPORT_DIR/net_latency_report.html"
mkdir -p "$REPORT_DIR"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
host=$(hostname)

TARGETS=("8.8.8.8" "1.1.1.1" "google.com" "cloudflare.com")
declare -A RTT_AVG RTT_STD LOSS

for t in "${TARGETS[@]}"; do
    RAW=$(ping -c 4 "$t" 2>/dev/null)
    if [[ -z "$RAW" ]]; then
        RTT_AVG["$t"]="N/A"
        RTT_STD["$t"]="N/A"
        LOSS["$t"]="100"
        continue
    fi

    LOSS["$t"]=$(echo "$RAW" | grep -o "[0-9]\+% packet loss" | grep -o "[0-9]\+")

    STAT=$(echo "$RAW" | grep "rtt min" | sed 's/.*= //')
    if [[ -z "$STAT" ]]; then
        RTT_AVG["$t"]="N/A"
        RTT_STD["$t"]="N/A"
    else
        RTT_AVG["$t"]=$(echo "$STAT" | cut -d'/' -f2)
        RTT_STD["$t"]=$(echo "$STAT" | cut -d'/' -f4)
    fi
done

echo "<!DOCTYPE html><html lang='ko'><head><meta charset='UTF-8'><title>네트워크 지연 분석 리포트</title>" > "$HTML_REPORT"

cat <<EOF >> "$HTML_REPORT"
<style>
    html { font-size:17px; }
    @media (max-width:1200px){ html{font-size:16px;} }
    @media (max-width:900px){ html{font-size:15px;} }
    @media (max-width:700px){ html{font-size:14px;} }
    @media (max-width:500px){ html{font-size:13px;} }

    body { background:#F5F6F8; color:#1B1E24; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; padding:40px; line-height:1.6; }
    h1 { font-size:2rem; margin-bottom:20px; }
    h2 { border-bottom:2px solid #E5E8F0; padding-bottom:6px; margin-top:45px; font-size:1.45rem; }
    .section { background:#FFFFFF; padding:22px 26px; border-radius:14px; box-shadow:0 4px 16px rgba(0,0,0,0.05); margin-top:20px; }
    table { width:100%; border-collapse:collapse; margin-top:12px; }
    th,td { border-bottom:1px solid #E5E8EB; padding:13px 12px; font-size:0.90rem; }
    th { background:#F3F6FA; color:#0079FF; border-bottom:2px solid #D7DCE3; }
    td { text-align:center; }
    tfoot td { color:#0079FF; font-weight:600; text-align:right; }
    .comment { background:#F3F6FF; color:#0079FF; padding:16px 18px; border-left:5px solid #0079FF; margin:22px 0; border-radius:8px; font-size:0.90rem; }
    .svgbox { background:#FFFFFF; border-radius:16px; padding:30px 0 38px 0; margin-top:24px; width:100%; overflow-x:auto; white-space:nowrap; box-shadow:0 6px 18px rgba(0,0,0,0.05); }
    svg rect { rx:7; transition:0.18s; transform-origin:bottom; }
    svg rect:hover { fill:#0079FF !important; filter:drop-shadow(0px -4px 6px rgba(0,121,255,0.35)); }
    svg text { font-size:13px; fill:#1B1E24; font-weight:500; }
    svg text[data-type=value] { font-weight:600; }
    svg line { stroke:#D5DBE4; stroke-width:2; }
    .ygrid { stroke:#EEF1F5; stroke-width:1; }

    @media (prefers-color-scheme: dark) {
        body { background:#1A1C1F; color:#E5EAF2; }
        h2 { border-bottom:2px solid #2A2D33; }
        .section { background:#24262B; box-shadow:0 4px 14px rgba(0,0,0,0.6); }
        table { color:#E5EAF2; }
        th { background:#2C3036; color:#5EA8FF; border-bottom:2px solid #3A3F47; }
        td { border-bottom:1px solid #3A3F47; }
        tfoot td { color:#5EA8FF; }
        .comment { background:#1F2633; color:#5EA8FF; border-left-color:#5EA8FF; }
        .svgbox { background:#24262B; box-shadow:0 6px 18px rgba(0,0,0,0.6); }
        svg text { fill:#E5EAF2; }
        .ygrid { stroke:#3A3F47; }
        svg line { stroke:#3A3F47; }
    }
</style>
</head><body>
<h1>네트워크 지연시간 분석 리포트</h1>

<div>호스트명: $host<br>수집 시간: $timestamp</div>

<h2>1. Ping 기반 지연시간 측정 결과</h2>
<div class="section">
<table>
    <thead>
        <tr>
            <th>대상 서버</th>
            <th>평균 RTT (ms)</th>
            <th>편차 (mdev)</th>
            <th>패킷 손실률 (%)</th>
        </tr>
    </thead>
    <tbody>
EOF

for t in "${TARGETS[@]}"; do
    echo "<tr><td>$t</td><td>${RTT_AVG[$t]}</td><td>${RTT_STD[$t]}</td><td>${LOSS[$t]}</td></tr>" >> "$HTML_REPORT"
done

echo "</tbody></table></div>" >> "$HTML_REPORT"

echo "<div class='comment'>Ping 결과를 기반으로 네트워크 품질을 진단합니다.</div>" >> "$HTML_REPORT"

# SVG BAR CHART -------------------------------------------------

# 최대 RTT 찾기
MAX_RTT=0
for t in "${TARGETS[@]}"; do
    val=$(echo "${RTT_AVG[$t]}" | sed 's/[^0-9.]//g')
    [[ -z "$val" ]] && continue
    (( $(echo "$val > $MAX_RTT" | bc -l) )) && MAX_RTT=$val
done

[[ $MAX_RTT == 0 ]] && MAX_RTT=1

BAR_WIDTH=70
BAR_GAP=45
LEFT=80
BOTTOM=40
SCALE=$(echo "200 / $MAX_RTT" | bc -l)
COUNT=${#TARGETS[@]}
WIDTH=$(( LEFT + COUNT*(BAR_WIDTH+BAR_GAP) + 80 ))

echo "<h2>2. 평균 RTT 시각화</h2>" >> "$HTML_REPORT"
echo "<div class='svgbox'><svg width='$WIDTH' height='320'>" >> "$HTML_REPORT"

BASELINE=$((300 - BOTTOM))

# y-grid
for y in 0 50 100 150 200; do
    YPOS=$(echo "$BASELINE - ($y * $SCALE)" | bc -l | cut -d'.' -f1)
    echo "<line x1='0' y1='$YPOS' x2='$WIDTH' y2='$YPOS' class='ygrid'></line>" >> "$HTML_REPORT"
done

X=$LEFT
for t in "${TARGETS[@]}"; do
    val=$(echo "${RTT_AVG[$t]}" | sed 's/[^0-9.]//g')
    [[ -z "$val" ]] && val=0
    H=$(echo "$val * $SCALE" | bc -l | cut -d'.' -f1)
    Y=$(( BASELINE - H ))

    echo "<rect x='$X' y='$Y' width='$BAR_WIDTH' height='$H' fill='#7DB7FF'></rect>" >> "$HTML_REPORT"
    echo "<text x='$((X + BAR_WIDTH/2))' y='$((BASELINE + 18))' text-anchor='middle'>$t</text>" >> "$HTML_REPORT"
    echo "<text x='$((X + BAR_WIDTH/2))' y='$((Y - 6))' data-type='value' text-anchor='middle'>$val</text>" >> "$HTML_REPORT"

    X=$(( X + BAR_WIDTH + BAR_GAP ))
done

echo "</svg></div>" >> "$HTML_REPORT"

echo "<h2>현재 시스템 네트워크 품질 종합 분석</h2>" >> "$HTML_REPORT"
echo "<div class='comment'>패킷 손실률과 평균 RTT를 분석하여 네트워크 상태를 요약합니다.</div>" >> "$HTML_REPORT"

echo "</body></html>" >> "$HTML_REPORT

