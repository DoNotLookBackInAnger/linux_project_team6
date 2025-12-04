#!/usr/bin/env bash

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
    LOSS_VAL=$(echo "$RAW" | grep -o "[0-9.]*% packet loss" | sed 's/%.*//')
    [[ -z "$LOSS_VAL" ]] && LOSS_VAL="100"
    LOSS["$t"]="$LOSS_VAL"
    RTT_LINE=$(echo "$RAW" | grep -E "rtt min|round-trip")
    if [[ -z "$RTT_LINE" ]]; then
        RTT_AVG["$t"]="N/A"
        RTT_STD["$t"]="N/A"
        continue
    fi
    NUMS=$(echo "$RTT_LINE" | sed 's/.*= //; s/ ms//')
    RTT_AVG["$t"]="$(echo "$NUMS" | cut -d'/' -f2)"
    RTT_STD["$t"]="$(echo "$NUMS" | cut -d'/' -f4)"
done

echo "<!DOCTYPE html><html lang='ko'><head><meta charset='UTF-8'><title>네트워크 지연 분석 리포트</title>" > "$HTML_REPORT"

cat <<EOF >> "$HTML_REPORT"
<style>
html { font-size:17px; } @media (max-width:1200px){ html{font-size:16px;} } @media (max-width:900px){ html{font-size:15px;} }
@media (max-width:700px){ html{font-size:14px;} } @media (max-width:500px){ html{font-size:13px;} }
body { background:#F5F6F8; color:#1B1E24; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; padding:40px; line-height:1.6; }
h1 { font-size:2rem; margin-bottom:20px; } h2 { border-bottom:2px solid #E5E8F0; padding-bottom:6px; margin-top:45px; font-size:1.45rem; }
.section { background:#FFFFFF; padding:22px 26px; border-radius:14px; box-shadow:0 4px 16px rgba(0,0,0,0.05); margin-top:20px; }
table { width:100%; border-collapse:collapse; margin-top:12px; }
th,td { border-bottom:1px solid #E5E8EB; padding:13px 12px; font-size:0.90rem; text-align:center; }
th { background:#F3F6FA; color:#0079FF; border-bottom:2px solid #D7DCE3; }
tr:hover { background:#E8F2FF; color:#0079FF; }
.comment { background:#F3F6FF; color:#0079FF; padding:16px 18px; border-left:5px solid #0079FF; margin:22px 0; border-radius:8px; font-size:0.94rem; }
.svgbox { background:#FFFFFF; border-radius:16px; padding:30px 0 38px 0; margin-top:24px; width:100%; overflow-x:auto; white-space:nowrap; box-shadow:0 6px 18px rgba(0,0,0,0.05); }
svg rect { rx:7; transition:0.18s; transform-origin:bottom; }
svg text { font-size:13px; fill:#1B1E24; font-weight:500; }
svg text[data-type=value] { font-weight:600; }
svg line { stroke:#D5DBE4; stroke-width:2; }
.ygrid { stroke:#EEF1F5; stroke-width:1; }
.active-row { background:#E8F2FF !important; color:#0079FF !important; font-weight:600; }

@media (prefers-color-scheme: dark) {
    body { background:#1A1C1F; color:#E5EAF2; }
    .section { background:#24262B; box-shadow:0 4px 14px rgba(0,0,0,0.6); }
    th { background:#2C3036; color:#5EA8FF; border-bottom:2px solid #3A3F47; }
    td { border-bottom:1px solid #3A3F47; }
    tr:hover { background:#1E2A3A; color:#5EA8FF; }
    .comment { background:#1F2633; color:#5EA8FF; border-left-color:#5EA8FF; }
    .svgbox { background:#24262B; box-shadow:0 6px 18px rgba(0,0,0,0.6); }
    svg text { fill:#E5EAF2; }
    .ygrid { stroke:#3A3F47; }
    svg line { stroke:#3A3F47; }
    .active-row { background:#1E2A3A !important; color:#5EA8FF !important; }
}
</style>
</head><body>
EOF

echo "<h1>네트워크 지연시간 분석 리포트</h1>" >> "$HTML_REPORT"
echo "<p>호스트: $host<br>생성 시각: $timestamp</p>" >> "$HTML_REPORT"

echo "<h2>1. Ping 측정 결과</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table><thead><tr><th>서버</th><th>RTT(ms)</th><th>STD</th><th>손실률(%)</th></tr></thead><tbody>" >> "$HTML_REPORT"

for t in "${TARGETS[@]}"; do
    echo "<tr><td>$t</td><td>${RTT_AVG[$t]}</td><td>${RTT_STD[$t]}</td><td>${LOSS[$t]}</td></tr>" >> "$HTML_REPORT"
done

echo "</tbody></table></div>" >> "$HTML_REPORT"

MAX_RTT=0
MAX_LOSS=0
MAX_STD=0

for t in "${TARGETS[@]}"; do
    r=$(echo "${RTT_AVG[$t]}" | sed 's/[^0-9.]//g')
    s=$(echo "${RTT_STD[$t]}" | sed 's/[^0-9.]//g')
    l=$(echo "${LOSS[$t]}" | sed 's/[^0-9.]//g')
    [[ -z "$r" ]] || (( $(awk -v a="$r" -v b="$MAX_RTT" 'BEGIN{print(a>b)}') )) && MAX_RTT="$r"
    [[ -z "$s" ]] || (( $(awk -v a="$s" -v b="$MAX_STD" 'BEGIN{print(a>b)}') )) && MAX_STD="$s"
    [[ -z "$l" ]] || (( $(awk -v a="$l" -v b="$MAX_LOSS" 'BEGIN{print(a>b)}') )) && MAX_LOSS="$l"
done

[[ "$MAX_RTT" == "0" ]] && MAX_RTT=1
[[ "$MAX_STD" == "0" ]] && MAX_STD=1
[[ "$MAX_LOSS" == "0" ]] && MAX_LOSS=1

BAR_WIDTH=70
BAR_GAP=60
LEFT_MARGIN=140
RIGHT_MARGIN=120
TOP_MARGIN=60
BOTTOM_MARGIN=90
BAR_MAX_H=250

graph() {
    TYPE=$1
    echo "<h2>$TYPE 시각화</h2>" >> "$HTML_REPORT"
    echo "<div class='svgbox'><svg width='900' height='$((TOP_MARGIN+BAR_MAX_H+BOTTOM_MARGIN))'>" >> "$HTML_REPORT"
    BASELINE=$((TOP_MARGIN+BAR_MAX_H))
    MAX_VAL=$2
    declare -n MAP=$3

    for i in {0..4}; do
        Y=$((BASELINE - (BAR_MAX_H*i/4)))
        V=$(awk -v m="$MAX_VAL" -v i="$i" 'BEGIN{printf "%.0f",m*i/4}')
        echo "<text x='$((LEFT_MARGIN-35))' y='$((Y+5))'>$V</text>" >> "$HTML_REPORT"
        echo "<line class='ygrid' x1='$LEFT_MARGIN' y1='$Y' x2='$((900-RIGHT_MARGIN))' y2='$Y'/>" >> "$HTML_REPORT"
    done

    echo "<line x1='$LEFT_MARGIN' y1='$BASELINE' x2='$((900-RIGHT_MARGIN))' y2='$BASELINE'/>" >> "$HTML_REPORT"
    echo "<line x1='$LEFT_MARGIN' y1='$TOP_MARGIN' x2='$LEFT_MARGIN' y2='$BASELINE'/>" >> "$HTML_REPORT"

    X=$LEFT_MARGIN
    for t in "${TARGETS[@]}"; do
        val="${MAP[$t]}"
        num=$(echo "$val" | sed 's/[^0-9.]//g')
        h=$(awk -v n="$num" -v mx="$MAX_VAL" -v bh="$BAR_MAX_H" 'BEGIN{printf "%.0f",n*bh/mx}')
        [[ "$h" -lt 10 ]] && h=10
        Y=$((BASELINE - h))

        if [[ "$num" == "$MAX_VAL" ]]; then
            COLOR="#0079FF"
        else
            COLOR="#DCEBFF"
        fi

        echo "<rect x='$X' y='$Y' width='$BAR_WIDTH' height='$h' fill='$COLOR'
        onmouseover=\"this.style.fill='#0079FF';this.style.filter='drop-shadow(0px -4px 6px rgba(0,121,255,0.35))';\"  
        onmouseout=\"this.style.fill='$COLOR';this.style.filter='none';\" />" >> "$HTML_REPORT"

        echo "<text data-type='value' x='$((X+5))' y='$((Y-10))'>$num</text>" >> "$HTML_REPORT"
        echo "<text x='$((X+BAR_WIDTH/2))' y='$((BASELINE+30))' text-anchor='middle'>$t</text>" >> "$HTML_REPORT"

        X=$((X+BAR_WIDTH+BAR_GAP))
    done
    echo "</svg></div>" >> "$HTML_REPORT"
}

graph "RTT(ms)" "$MAX_RTT" RTT_AVG
graph "손실률(%)" "$MAX_LOSS" LOSS
graph "지연 편차(STD)" "$MAX_STD" RTT_STD

BEST_RTT=999999
WORST_LOSS=0
BEST_STD=0

for t in "${TARGETS[@]}"; do
    a=$(echo "${RTT_AVG[$t]}" | sed 's/[^0-9.]//g')
    s=$(echo "${RTT_STD[$t]}" | sed 's/[^0-9.]//g')
    l=$(echo "${LOSS[$t]}" | sed 's/[^0-9.]//g')

    [[ -n "$a" ]] && (( $(awk -v a="$a" -v b="$BEST_RTT" 'BEGIN{print(a<b)}') )) && BEST_RTT="$a"
    [[ -n "$l" ]] && (( $(awk -v a="$l" -v b="$WORST_LOSS" 'BEGIN{print(a>b)}') )) && WORST_LOSS="$l"
    [[ -n "$s" ]] && (( $(awk -v a="$s" -v b="$BEST_STD" 'BEGIN{print(a>b)}') )) && BEST_STD="$s"
done

if [[ $(awk -v l="$WORST_LOSS" -v r="$BEST_RTT" 'BEGIN{print(l==0 && r==999999)}') -eq 1 ]]; then 
    FINAL="측정 정보 부족으로 분석이 불가능합니다."
else
    if [[ $(awk -v l="$WORST_LOSS" 'BEGIN{print(l>=21)}') -eq 1 ]]; then FINAL="손실률이 높아 즉각 조치가 필요합니다."
    elif [[ $(awk -v l="$WORST_LOSS" 'BEGIN{print(l>=6)}') -eq 1 ]]; then FINAL="손실률 증가로 품질 저하가 발생 중입니다."
    elif [[ $(awk -v r="$BEST_RTT" 'BEGIN{print(r>=151)}') -eq 1 ]]; then FINAL="지연이 매우 심각한 상태입니다."
    elif [[ $(awk -v r="$BEST_RTT" 'BEGIN{print(r>=81)}') -eq 1 ]]; then FINAL="지연 상승이 감지되었습니다."
    elif [[ $(awk -v l="$WORST_LOSS" -v r="$BEST_RTT" 'BEGIN{print(l<=5 && r<=80)}') -eq 1 ]]; then FINAL="전반적으로 안정적인 네트워크 상태입니다."
    else FINAL="약간의 손실이 있으나 연결은 유지됩니다."
    fi

    if [[ $(awk -v s="$BEST_STD" 'BEGIN{print(s>=16)}') -eq 1 ]]; then FINAL="$FINAL (지연 변동 폭이 매우 큼)"
    elif [[ $(awk -v s="$BEST_STD" 'BEGIN{print(s>=6)}') -eq 1 ]]; then FINAL="$FINAL (지연 변동이 있어 관찰 필요)"
    fi
fi

echo "<h2>3. 종합 네트워크 품질 분석</h2>" >> "$HTML_REPORT"

LOSS_ARC=$(awk -v x="$WORST_LOSS" 'BEGIN{printf("%.1f", 377*(x/100))}')

cat <<EOF >> "$HTML_REPORT"
<div class="section net-summary">

<div class="net-table">
<table>
<thead>
<tr><th>항목 (Item)</th><th>값 (Value)</th></tr>
</thead>
<tbody>
<tr><td>현재 최소 RTT</td><td>${BEST_RTT} ms</td></tr>
<tr><td>현재 최대 STD</td><td>${BEST_STD} ms</td></tr>
</tbody>
</table>
</div>

<div class="net-donut">
<svg width="160" height="160">
<circle cx="80" cy="80" r="60" stroke="#E5E8F0" stroke-width="14" fill="none"/>
<circle cx="80" cy="80" r="60" stroke="#0079FF" stroke-width="14" fill="none"
stroke-dasharray="${LOSS_ARC},377"
stroke-linecap="round" transform="rotate(-90 80 80)"/>
</svg>
<div class="donut-text">${WORST_LOSS}%<div class="donut-sub">최대 손실률</div></div>
</div>

</div>

<div class="comment">$FINAL</div>

<style>
.net-summary {
    display:flex;
    justify-content:space-between;
    align-items:center;
    gap:40px;
    padding:28px 20px;
}
.net-table { width:100%; }
.net-table table { width:100%; border-collapse:collapse; }
.net-donut {
    position:relative;
    width:160px;
    height:160px;
    flex-shrink:0;
    margin-left:auto;
}
.donut-text {
    position:absolute;
    top:50%; left:50%;
    transform:translate(-50%,-50%);
    font-size:1.15rem; font-weight:700;
    text-align:center;
}
.donut-sub {
    font-size:0.75rem;
    font-weight:400;
    margin-top:2px;
}
@media (max-width:780px) {
    .net-summary {
        flex-direction:column;
        align-items:flex-start;
    }
    .net-donut {
        margin:20px auto 0 auto;
    }
}
</style>
EOF


highlight_rtt_severe=$(awk -v r="$BEST_RTT" 'BEGIN{print(r>=151)}')
highlight_rtt_warning=$(awk -v r="$BEST_RTT" 'BEGIN{print(r>=81 && r<151)}')
highlight_rtt_normal=$(awk -v r="$BEST_RTT" 'BEGIN{print(r<=80)}')

highlight_std_severe=$(awk -v s="$BEST_STD" 'BEGIN{print(s>=16)}')
highlight_std_warning=$(awk -v s="$BEST_STD" 'BEGIN{print(s>=6 && s<16)}')
highlight_std_normal=$(awk -v s="$BEST_STD" 'BEGIN{print(s<6)}')

highlight_loss_severe=$(awk -v l="$WORST_LOSS" 'BEGIN{print(l>=21)}')
highlight_loss_warning=$(awk -v l="$WORST_LOSS" 'BEGIN{print(l>=6 && l<21)}')
highlight_loss_normal=$(awk -v l="$WORST_LOSS" 'BEGIN{print(l<=5)}')

echo "<h2>네트워크 품질 평가 기준표</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table><thead><tr><th>항목</th><th>단계</th><th>기준</th></tr></thead><tbody>" >> "$HTML_REPORT"

row() { echo "<tr class='$1'><td>$2</td><td>$3</td><td>$4</td></tr>" >> "$HTML_REPORT"; }

row "$( [[ "$highlight_rtt_severe" -eq 1 ]] && echo active-row )" "RTT" "심각" "RTT ≥ 151ms"
row "$( [[ "$highlight_rtt_warning" -eq 1 ]] && echo active-row )" "RTT" "증가" "RTT ≥ 81ms"
row "$( [[ "$highlight_rtt_normal" -eq 1 ]] && echo active-row )" "RTT" "정상" "RTT ≤ 80ms"

row "$( [[ "$highlight_std_severe" -eq 1 ]] && echo active-row )" "STD" "심각" "STD ≥ 16"
row "$( [[ "$highlight_std_warning" -eq 1 ]] && echo active-row )" "STD" "주의" "STD ≥ 6"
row "$( [[ "$highlight_std_normal" -eq 1 ]] && echo active-row )" "STD" "안정" "STD < 6"

row "$( [[ "$highlight_loss_severe" -eq 1 ]] && echo active-row )" "손실률" "심각" "Loss ≥ 21%"
row "$( [[ "$highlight_loss_warning" -eq 1 ]] && echo active-row )" "손실률" "주의" "Loss ≥ 6%"
row "$( [[ "$highlight_loss_normal" -eq 1 ]] && echo active-row )" "손실률" "안정" "Loss ≤ 5%"

echo "</tbody></table></div>" >> "$HTML_REPORT"

echo "</body></html>" >> "$HTML_REPORT"

if command -v open >/dev/null 2>&1; then
    open "$HTML_REPORT"      
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$HTML_REPORT"    
fi
echo "HTML Report saved to: $HTML_REPORT"
echo "Done."
