#!/usr/local/bin/bash

REPORT_DIR="./reports"
HTML_REPORT="$REPORT_DIR/net_ports_report.html"
mkdir -p "$REPORT_DIR"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
host=$(hostname)

DANGER_PORTS=("22" "23" "3389" "5900" "3306" "1433")

declare -A SERVICE_DESC=(
    ["22"]="SSH 원격 접속"
    ["23"]="Telnet (암호화 없음)"
    ["80"]="HTTP 웹 서비스"
    ["443"]="HTTPS 보안 웹 서비스"
    ["3306"]="MySQL DB"
    ["3389"]="RDP 원격 데스크탑"
    ["5900"]="VNC 원격 제어"
    ["1433"]="MS-SQL 서버"
)

MAX_COUNTRY_COUNT=0

LISTEN=$(netstat -an | grep LISTEN)
declare -A DANGER_STATUS
for port in "${DANGER_PORTS[@]}"; do
    if echo "$LISTEN" | grep -q ":$port"; then
        DANGER_STATUS["$port"]="사용 중"
    else
        DANGER_STATUS["$port"]="열려 있지 않음"
    fi
done

EST=$(netstat -an | grep ESTABLISHED)
IPS=$(echo "$EST" | awk '{print $5}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | uniq)

declare -A COUNTRY_COUNT
for ip in $IPS; do
    c=$(curl -s "https://ipinfo.io/$ip/country")
    [ -z "$c" ] && c="알수없음"
    next_count=$((COUNTRY_COUNT["$c"] + 1))
    if ((MAX_COUNTRY_COUNT < next_count)); then 
        MAX_COUNTRY_COUNT=$next_count 
    fi
    COUNTRY_COUNT["$c"]=$next_count
done

PROCLIST=$(lsof -i | awk 'NR>1{print $1}' | sort | uniq -c | sort -nr | head -15)

cat <<EOF > "$HTML_REPORT"
<html>
<head>
<meta charset="UTF-8">
<title>네트워크 분석 리포트</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
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

    /* 다크모드 자동 감지 */
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
</head>
<body>

<h1>네트워크 상태 분석 리포트</h1>
<p>호스트: $host<br>생성 시각: $timestamp</p>
EOF

echo "<h2>1. 사용 중인 포트 목록</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>프로토콜</th><th>로컬 주소</th><th>상대 주소</th><th>상태</th></tr>" >> "$HTML_REPORT"

if [ -z "$LISTEN" ]; then
    echo "<tr><td colspan='4'>열린 포트 없음</td></tr>" >> "$HTML_REPORT"
else
    echo "$LISTEN" | awk '{printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",$1,$4,$5,$NF}' >> "$HTML_REPORT"
fi

PC=$(echo "$LISTEN" | wc -l | tr -d ' ')
echo "<tfoot><tr><td colspan='4'>합계: $PC</td></tr></tfoot>" >> "$HTML_REPORT"

echo "</table>" >> "$HTML_REPORT"

if (( PC == 0 )); then PC_C="현재 포트가 전혀 열려 있지 않아 가장 안전한 상태입니다."
elif (( PC <= 15 )); then PC_C="필수 서비스 중심의 가벼운 운영 환경입니다."
elif (( PC <= 50 )); then PC_C="표준 macOS/개발환경 수준의 정상적인 포트 사용입니다."
elif (( PC <= 150 )); then PC_C="백엔드 서비스 또는 개발 도구가 다수 동작 중일 가능성이 있습니다."
else PC_C="포트 개수가 비정상적으로 많습니다. 서버형 또는 과도한 프로세스가 동작 중일 수 있습니다."
fi

echo "<div class='comment'>$PC_C</div></div>" >> "$HTML_REPORT"


echo "<h2>2. 위험 포트 점검</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>포트</th><th>설명</th><th>상태</th></tr>" >> "$HTML_REPORT"

for port in "${DANGER_PORTS[@]}"; do
    echo "<tr><td>$port</td><td>${SERVICE_DESC[$port]}</td><td>${DANGER_STATUS[$port]}</td></tr>" >> "$HTML_REPORT"
done

echo "<tfoot><tr><td colspan='3'>합계: ${#DANGER_PORTS[@]}</td></tr></tfoot>" >> "$HTML_REPORT"
echo "</table>" >> "$HTML_REPORT"

if printf "%s" "${DANGER_STATUS[@]}" | grep -q "사용 중"; then
    DC="일부 위험 포트가 열려 있습니다. 접근 통제 필요."
else
    DC="모든 위험 포트가 닫혀 있어 안전한 상태입니다."
fi
echo "<div class='comment'>$DC</div></div>" >> "$HTML_REPORT"


echo "<h2>3. 연결된 세션(ESTABLISHED)</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>프로토콜</th><th>로컬</th><th>상대</th><th>상태</th></tr>" >> "$HTML_REPORT"

echo "$EST" | awk '{printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",$1,$4,$5,$NF}' >> "$HTML_REPORT"

EC=$(echo "$EST" | wc -l | tr -d ' ')
echo "<tfoot><tr><td colspan='4'>합계: $EC</td></tr></tfoot>" >> "$HTML_REPORT"

echo "</table>" >> "$HTML_REPORT"
if [ -z "$EST" ]; then ES_C="외부 연결 없음."
else ES_C="클라우드, CDN, 업데이트 서버와의 통신이 이루어지고 있습니다."
fi
echo "<div class='comment'>$ES_C</div></div>" >> "$HTML_REPORT"


echo "<h2>4. 국가 기반 분석</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>국가</th><th>요청 수</th></tr>" >> "$HTML_REPORT"

TOTAL_COUNTRY=0
for c in "${!COUNTRY_COUNT[@]}"; do
    TOTAL_COUNTRY=$((TOTAL_COUNTRY + COUNTRY_COUNT[$c]))
    echo "<tr><td>$c</td><td>${COUNTRY_COUNT[$c]}</td></tr>" >> "$HTML_REPORT"
done

echo "<tfoot><tr><td colspan='2'>합계: $TOTAL_COUNTRY</td></tr></tfoot>" >> "$HTML_REPORT"
echo "</table>" >> "$HTML_REPORT"

CT=${#COUNTRY_COUNT[@]}
if (( CT <= 1 )); then GEO_C="특정 국가 중심 통신으로 정상 범주입니다."
elif (( CT <= 4 )); then GEO_C="다양한 국가와 통신 중이며 CDN·클라우드 가능성이 높습니다."
else GEO_C="해외 통신 국가가 과도하게 많습니다. 점검이 필요합니다."
fi
echo "<div class='comment'>$GEO_C</div>" >> "$HTML_REPORT"


BAR_COUNT=${#COUNTRY_COUNT[@]}
BASE_MIN_WIDTH=720
NAME_MAX_LEN=0
for c in "${!COUNTRY_COUNT[@]}"; do
    l=${#c}
    (( l > NAME_MAX_LEN )) && NAME_MAX_LEN=$l
done
NAME_PADDING=$(( NAME_MAX_LEN * 8 ))
if (( BAR_COUNT <= 3 )); then BAR_WIDTH=90; BAR_GAP=60
elif (( BAR_COUNT <= 6 )); then BAR_WIDTH=70; BAR_GAP=50
elif (( BAR_COUNT <= 10 )); then BAR_WIDTH=55; BAR_GAP=40
else BAR_WIDTH=45; BAR_GAP=35
fi

LEFT_MARGIN=$(( 140 + NAME_PADDING ))
RIGHT_MARGIN=120
TOP_MARGIN=60
BOTTOM_MARGIN=85
BAR_MAX_H=250
SVG_WIDTH_RAW=$(( LEFT_MARGIN + RIGHT_MARGIN + BAR_COUNT*(BAR_WIDTH+BAR_GAP) ))
SVG_WIDTH=$(( SVG_WIDTH_RAW < BASE_MIN_WIDTH ? BASE_MIN_WIDTH : SVG_WIDTH_RAW ))
SVG_HEIGHT=$(( TOP_MARGIN + BAR_MAX_H + BOTTOM_MARGIN ))
BASELINE=$(( TOP_MARGIN + BAR_MAX_H ))
MAX_COUNTRY_COUNT=0
for c in "${!COUNTRY_COUNT[@]}"; do
    (( COUNTRY_COUNT[$c] > MAX_COUNTRY_COUNT )) && MAX_COUNTRY_COUNT=${COUNTRY_COUNT[$c]}
done

echo "<div class='svgbox'><svg width='$SVG_WIDTH' height='$SVG_HEIGHT'>" >> "$HTML_REPORT"

Y_STEP=$(( MAX_COUNTRY_COUNT / 4 ))
for i in {0..4}; do
    YVAL=$(( i * Y_STEP ))
    YPOS=$(( BASELINE - (BAR_MAX_H * i / 4) ))
    echo "<text x='$((LEFT_MARGIN-35))' y='$((YPOS+5))'>$YVAL</text>" >> "$HTML_REPORT"
    echo "<line class='ygrid' x1='$LEFT_MARGIN' y1='$YPOS' x2='$((SVG_WIDTH-RIGHT_MARGIN))' y2='$YPOS'/>" >> "$HTML_REPORT"
done

echo "<line x1='$LEFT_MARGIN' y1='$BASELINE' x2='$((SVG_WIDTH-RIGHT_MARGIN))' y2='$BASELINE'/>" >> "$HTML_REPORT"
echo "<line x1='$LEFT_MARGIN' y1='$TOP_MARGIN' x2='$LEFT_MARGIN' y2='$BASELINE'/>" >> "$HTML_REPORT"

X=$LEFT_MARGIN
for c in "${!COUNTRY_COUNT[@]}"; do
    ct=${COUNTRY_COUNT[$c]}
    h=$(( ct * BAR_MAX_H / MAX_COUNTRY_COUNT ))
    (( h < 10 )) && h=10
    Y=$(( BASELINE - h ))
    short_c="$c"
    (( ${#short_c} > 8 )) && short_c="${short_c:0:8}…"
    COLOR="#DCEBFF"
    (( ct == MAX_COUNTRY_COUNT )) && COLOR="#0079FF"
    echo "<rect x='$X' y='$Y' width='$BAR_WIDTH' height='$h' fill='$COLOR'/>" >> "$HTML_REPORT"
    echo "<text data-type='value' x='$((X+8))' y='$((Y-12))'>$ct</text>" >> "$HTML_REPORT"
    echo "<text x='$((X + BAR_WIDTH/2))' y='$((BASELINE+32))' text-anchor='middle'>$short_c</text>" >> "$HTML_REPORT"
    X=$(( X + BAR_WIDTH + BAR_GAP ))
done
echo "</svg></div>" >> "$HTML_REPORT"


echo "<h2>5. 프로세스별 소켓 사용량</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>사용량</th><th>프로세스</th></tr>" >> "$HTML_REPORT"

TOTAL_PROC=0
while read -r line; do
    ct=$(echo "$line" | awk '{print $1}')
    pr=$(echo "$line" | awk '{print $2}')
    TOTAL_PROC=$((TOTAL_PROC + ct))
    echo "<tr><td>${ct}</td><td>${pr}</td></tr>" >> "$HTML_REPORT"
done <<< "$PROCLIST"

echo "<tfoot><tr><td colspan='2'>합계: $TOTAL_PROC</td></tr></tfoot>" >> "$HTML_REPORT"
echo "</table>" >> "$HTML_REPORT"

TPC=$(echo "$PROCLIST" | head -1 | awk '{print $1}')
if (( TPC < 5 )); then PROC_C="네트워크 사용량이 낮은 편입니다."
elif (( TPC < 20 )); then PROC_C="일부 앱이 네트워크를 적당히 사용 중입니다."
else PROC_C="특정 프로세스가 과도한 트래픽을 발생시키고 있을 수 있습니다."
fi
echo "<div class='comment'>$PROC_C</div></div>" >> "$HTML_REPORT"


NAME_MAX_LEN=0
while read -r line; do
    pr=$(echo "$line" | awk '{print $2}')
    len=${#pr}
    (( len > NAME_MAX_LEN )) && NAME_MAX_LEN=$len
done <<< "$PROCLIST"
NAME_PADDING=$(( NAME_MAX_LEN * 7 ))

BAR_COUNT=$(echo "$PROCLIST" | wc -l)
if (( BAR_COUNT <= 3 )); then BAR_WIDTH=90; BAR_GAP=60
elif (( BAR_COUNT <= 6 )); then BAR_WIDTH=70; BAR_GAP=50
elif (( BAR_COUNT <= 10 )); then BAR_WIDTH=55; BAR_GAP=40
else BAR_WIDTH=45; BAR_GAP=35
fi

LEFT_MARGIN=$(( 140 + NAME_PADDING ))
RIGHT_MARGIN=120
TOP_MARGIN=60
BOTTOM_MARGIN=85
BAR_MAX_H=250
BASE_MIN_WIDTH=720

SVG_WIDTH_RAW=$(( LEFT_MARGIN + BAR_COUNT*(BAR_WIDTH+BAR_GAP) + RIGHT_MARGIN ))
SVG_WIDTH=$(( SVG_WIDTH_RAW < BASE_MIN_WIDTH ? BASE_MIN_WIDTH : SVG_WIDTH_RAW ))
SVG_HEIGHT=$(( TOP_MARGIN + BAR_MAX_H + BOTTOM_MARGIN ))
BASELINE=$(( TOP_MARGIN + BAR_MAX_H ))
MAX_PROC_COUNT=$(echo "$PROCLIST" | head -1 | awk '{print $1}')

echo "<div class='svgbox'><svg width='$SVG_WIDTH' height='$SVG_HEIGHT'>" >> "$HTML_REPORT"

Y_STEP=$(( MAX_PROC_COUNT / 4 ))
for i in {0..4}; do
    YVAL=$(( i * Y_STEP ))
    YPOS=$(( BASELINE - (BAR_MAX_H * i / 4) ))
    echo "<text x='$((LEFT_MARGIN-35))' y='$((YPOS+5))'>$YVAL</text>" >> "$HTML_REPORT"
    echo "<line class='ygrid' x1='$LEFT_MARGIN' y1='$YPOS' x2='$((SVG_WIDTH-RIGHT_MARGIN))' y2='$YPOS'/>" >> "$HTML_REPORT"
done

echo "<line x1='$LEFT_MARGIN' y1='$BASELINE' x2='$((SVG_WIDTH-RIGHT_MARGIN))' y2='$BASELINE'/>" >> "$HTML_REPORT"
echo "<line x1='$LEFT_MARGIN' y1='$TOP_MARGIN' x2='$LEFT_MARGIN' y2='$BASELINE'/>" >> "$HTML_REPORT"

X=$LEFT_MARGIN
while read -r line; do
    ct=$(echo "$line" | awk '{print $1}')
    pr=$(echo "$line" | awk '{print $2}')
    short_pr="$pr"
    (( ${#short_pr} > 10 )) && short_pr="${short_pr:0:10}…"
    h=$(( ct * BAR_MAX_H / MAX_PROC_COUNT ))
    (( h < 10 )) && h=10
    Y=$(( BASELINE - h ))
    COLOR="#DCEBFF"
    (( ct == MAX_PROC_COUNT )) && COLOR="#0079FF"
    echo "<rect x='$X' y='$Y' width='$BAR_WIDTH' height='$h' fill='$COLOR' />" >> "$HTML_REPORT"
    echo "<text data-type='value' x='$((X+8))' y='$((Y-10))'>$ct</text>" >> "$HTML_REPORT"
    echo "<text x='$((X + BAR_WIDTH/2))' y='$((BASELINE+32))' text-anchor='middle' font-size='12'>$short_pr</text>" >> "$HTML_REPORT"
    X=$(( X + BAR_WIDTH + BAR_GAP ))
done <<< "$PROCLIST"
echo "</svg></div>" >> "$HTML_REPORT"


echo "<h2>현재 시스템 네트워크 상태 종합 분석</h2>" >> "$HTML_REPORT"
echo "<div class='comment' style='border-left-color:#0079FF; color:#0079FF'>" >> "$HTML_REPORT"

RISK=0
[[ "$DC" == *"열려"* ]] && RISK=$((RISK+2))
(( CT > 4 )) && RISK=$((RISK+1))
(( TPC > 20 )) && RISK=$((RISK+1))
(( PC > 150 )) && RISK=$((RISK+1))

if (( RISK == 0 )); then FINAL="종합적으로 매우 안정적인 네트워크 환경입니다."; COLOR="#0079FF"
elif (( RISK == 1 )); then FINAL="일부 요소에 주의가 필요하지만 대체로 정상 범주입니다."; COLOR="#0079FF"
elif (( RISK == 2 )); then FINAL="몇 가지 위험 요소가 있으므로 점검을 권장합니다."; COLOR="#CC4A4A"
else FINAL="다수의 위험 지표가 감지되며 자세한 분석이 필요합니다."; COLOR="#BF1A1A"
fi

echo "<span style='color:$COLOR'>$FINAL</span>" >> "$HTML_REPORT"
echo "</div></body></html>" >> "$HTML_REPORT"

open "$HTML_REPORT"
echo "HTML Report saved to: $HTML_REPORT"
echo "Done."
