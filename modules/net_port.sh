#!/usr/bin/env bash

REPORT_DIR="./reports"
HTML_REPORT="$REPORT_DIR/net_ports_report.html"
mkdir -p "$REPORT_DIR"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
host=$(hostname)

DANGER_PORTS=("22" "23" "3389" "5900" "3306" "1433")

declare -A SERVICE_DESC=(
    ["22"]="SSH 원격 접속"
    ["23"]="Telnet"
    ["80"]="HTTP"
    ["443"]="HTTPS"
    ["3306"]="MySQL"
    ["3389"]="RDP"
    ["5900"]="VNC"
    ["1433"]="MS-SQL"
)

LISTEN=$(netstat -an | grep LISTEN | grep -Ev "^unix")
declare -A DANGER_STATUS
for port in "${DANGER_PORTS[@]}"; do
    if echo "$LISTEN" | grep -q ":$port"; then
        DANGER_STATUS["$port"]="사용 중"
    else
        DANGER_STATUS["$port"]="닫힘"
    fi
done

EST=$(netstat -an | grep ESTABLISHED)
IPS=$(echo "$EST" | awk '{print $5}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | uniq)

declare -A COUNTRY_COUNT
MAX_COUNTRY_COUNT=0
for ip in $IPS; do
    if [[ "$ip" =~ ^127\. ]] || [[ "$ip" =~ ^192\.168\. ]] || [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        c="LOCAL"
    else
        c=$(curl -s "https://ipinfo.io/$ip/country" 2>/dev/null)
        if [[ -z "$c" ]] || [[ "$c" =~ "error" ]] || [[ "$c" =~ "bogon" ]]; then
            c="UNKNOWN"
        fi
    fi
    new_val=$((COUNTRY_COUNT["$c"] + 1))
    COUNTRY_COUNT["$c"]=$new_val
    ((new_val > MAX_COUNTRY_COUNT)) && MAX_COUNTRY_COUNT=$new_val
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
    th,td { border-bottom:1px solid #E5E8EB; padding:13px 12px; font-size:0.90rem; text-align:center; }
    th { background:#F3F6FA; color:#0079FF; border-bottom:2px solid #D7DCE3; }
    tr:hover { background:#E8F2FF; color:#0079FF; }
    tfoot td { color:#0079FF; font-weight:600; text-align:right; }
    .comment { background:#F3F6FF; color:#0079FF; padding:16px 18px; border-left:5px solid #0079FF; margin:22px 0; border-radius:8px; font-size:0.90rem; }
    .svgbox { background:#FFFFFF; border-radius:16px; padding:30px 0 38px 0; margin-top:24px; width:100%; overflow-x:auto; white-space:nowrap; box-shadow:0 6px 18px rgba(0,0,0,0.05); }
    svg rect { rx:7; transition:0.18s; transform-origin:bottom; }
    svg text { font-size:13px; fill:#1B1E24; font-weight:500; }
    .ygrid { stroke:#EEF1F5; stroke-width:1; }
    .active-row { background:#E8F2FF !important; color:#0079FF !important; font-weight:600 !important; }
    @media (prefers-color-scheme: dark) {
        body { background:#1A1C1F; color:#E5EAF2; }
        h2 { border-bottom:2px solid #2A2D33; }
        .section { background:#24262B; box-shadow:0 4px 14px rgba(0,0,0,0.6); }
        th { background:#2C3036; color:#5EA8FF; border-bottom:2px solid #3A3F47; }
        td { border-bottom:1px solid #3A3F47; }
        tr:hover { background:#1E2A3A; color:#5EA8FF; }
        tfoot td { color:#5EA8FF; }
        .comment { background:#1F2633; color:#5EA8FF; border-left-color:#5EA8FF; }
        .svgbox { background:#24262B; box-shadow:0 6px 18px rgba(0,0,0,0.6); }
        svg text { fill:#E5EAF2; }
        .ygrid { stroke:#3A3F47; }
        svg line { stroke:#3A3F47; }
        .active-row { background:#1E2A3A !important; color:#5EA8FF !important; font-weight:600 !important; }
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
echo "<tfoot><tr><td colspan='4'>합계: $PC</td></tr></tfoot></table>" >> "$HTML_REPORT"

if (( PC == 0 )); then
    PC_C="현재 열려 있는 포트가 없습니다. 매우 안전한 상태입니다."
elif (( PC <= 30 )); then
    PC_C="기본 서비스 중심의 정상적인 포트 사용량입니다."
elif (( PC <= 100 )); then
    PC_C="일반적인 macOS·개발 환경에서 흔히 발생하는 포트 수입니다."
elif (( PC <= 200 )); then
    PC_C="네트워크 기반 서비스가 다수 실행 중인 환경으로 보통 수준의 부하입니다."
else
    PC_C="포트 사용량이 과도합니다. 서버형 패턴 또는 비정상적인 프로세스 가능성이 있습니다."
fi

echo "<div class='comment'>$PC_C</div></div>" >> "$HTML_REPORT"

echo "<h2>2. 위험 포트 점검</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>포트</th><th>설명</th><th>상태</th></tr>" >> "$HTML_REPORT"

for port in "${DANGER_PORTS[@]}"; do
    echo "<tr><td>$port</td><td>${SERVICE_DESC[$port]}</td><td>${DANGER_STATUS[$port]}</td></tr>" >> "$HTML_REPORT"
done

echo "<tfoot><tr><td colspan='3'>합계: ${#DANGER_PORTS[@]}</td></tr></tfoot></table>" >> "$HTML_REPORT"

if printf "%s" "${DANGER_STATUS[@]}" | grep -q "사용 중"; then
    DC="위험 포트가 열려 있습니다. 불필요한 경우 즉시 비활성화를 권장합니다."
else
    DC="모든 위험 포트가 닫혀 있어 안전한 상태입니다."
fi

echo "<div class='comment'>$DC</div></div>" >> "$HTML_REPORT"

echo "<h2>3. ESTABLISHED 연결 분석</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>프로토콜</th><th>로컬</th><th>상대</th><th>상태</th></tr>" >> "$HTML_REPORT"

echo "$EST" | awk '{printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",$1,$4,$5,$NF}' >> "$HTML_REPORT"

EC=$(echo "$EST" | wc -l | tr -d ' ')
echo "<tfoot><tr><td colspan='4'>합계: $EC</td></tr></tfoot></table>" >> "$HTML_REPORT"

if (( EC == 0 )); then
    ES_C="활성 네트워크 세션이 없습니다."
elif (( EC <= 100 )); then
    ES_C="일반 애플리케이션 및 브라우저 통신 수준의 정상적인 세션 수입니다."
elif (( EC <= 300 )); then
    ES_C="온라인 서비스·브라우저 탭이 다수 열려 있어 세션 수가 증가한 상태입니다."
else
    ES_C="세션 수가 과도합니다. 일부 앱의 비정상적인 연결 유지 또는 트래픽 폭주가 의심됩니다."
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

CT=${#COUNTRY_COUNT[@]}

echo "<tfoot><tr><td colspan='2'>국가 수: $CT</td></tr></tfoot></table>" >> "$HTML_REPORT"

if (( CT <= 1 )); then
    GEO_C="단일 국가 중심의 안정적인 통신 패턴입니다."
elif (( CT <= 4 )); then
    GEO_C="CDN·클라우드와의 통신이 포함된 정상적인 글로벌 트래픽입니다."
elif (( CT <= 7 )); then
    GEO_C="다수 국가와 통신 중입니다. CDN일 가능성이 높지만 확인이 필요합니다."
else
    GEO_C="해외 통신 국가 수가 과도합니다. 의심스러운 연결 가능성이 있습니다."
fi

echo "<div class='comment'>$GEO_C</div>" >> "$HTML_REPORT"

BAR_COUNT=$CT
BASE_MIN_WIDTH=720
NAME_MAX_LEN=0

for c in "${!COUNTRY_COUNT[@]}"; do
    l=${#c}
    (( l > NAME_MAX_LEN )) && NAME_MAX_LEN=$l
done

NAME_PADDING=$(( NAME_MAX_LEN * 8 ))

if (( BAR_COUNT <= 3 )); then
    BAR_WIDTH=90
    BAR_GAP=60
elif (( BAR_COUNT <= 6 )); then
    BAR_WIDTH=70
    BAR_GAP=50
elif (( BAR_COUNT <= 10 )); then
    BAR_WIDTH=55
    BAR_GAP=40
else
    BAR_WIDTH=45
    BAR_GAP=35
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

echo "<div class='svgbox'><svg width='$SVG_WIDTH' height='$SVG_HEIGHT'>" >> "$HTML_REPORT"

Y_STEP=$(( MAX_COUNTRY_COUNT / 4 ))
(( Y_STEP == 0 )) && Y_STEP=1

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

    echo "<rect x='$X' y='$Y' width='$BAR_WIDTH' height='$h' fill='$COLOR' 
    onmouseover=\"this.style.fill='#0079FF';this.style.filter='drop-shadow(0 -4px 6px rgba(0,121,255,0.35))';\" 
    onmouseout=\"this.style.fill='$COLOR';this.style.filter='none';\" />" >> "$HTML_REPORT"

    echo "<text x='$((X+8))' y='$((Y-12))'>$ct</text>" >> "$HTML_REPORT"
    echo "<text x='$((X + BAR_WIDTH/2))' y='$((BASELINE+32))' text-anchor='middle'>$short_c</text>" >> "$HTML_REPORT"

    X=$(( X + BAR_WIDTH + BAR_GAP ))
done

echo "</svg></div></div>" >> "$HTML_REPORT"
echo "<h2>5. 프로세스별 소켓 사용량</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>소켓 수</th><th>프로세스</th></tr>" >> "$HTML_REPORT"

TOTAL_PROC=0
while read -r line; do
    ct=$(echo "$line" | awk '{print $1}')
    pr=$(echo "$line" | awk '{print $2}')
    TOTAL_PROC=$((TOTAL_PROC + ct))
    echo "<tr><td>$ct</td><td>$pr</td></tr>" >> "$HTML_REPORT"
done <<< "$PROCLIST"

echo "<tfoot><tr><td colspan='2'>총합: $TOTAL_PROC</td></tr></tfoot></table>" >> "$HTML_REPORT"

TPC=$(echo "$PROCLIST" | head -1 | awk '{print $1}')

if (( TPC < 50 )); then
    PROC_C="네트워크 소켓 사용량이 낮은 편입니다."
elif (( TPC < 150 )); then
    PROC_C="일반적인 브라우저·개발 도구 환경에서 정상적인 수준입니다."
elif (( TPC < 400 )); then
    PROC_C="특정 애플리케이션이 다수의 네트워크 연결을 유지 중입니다."
else
    PROC_C="소켓 사용량이 매우 높습니다. 브라우저 과부하 또는 네트워크 누수 가능성이 있습니다."
fi

echo "<div class='comment'>$PROC_C</div></div>" >> "$HTML_REPORT"

NAME_MAX_LEN=0
while read -r line; do
    name=$(echo "$line" | awk '{print $2}')
    len=${#name}
    (( len > NAME_MAX_LEN )) && NAME_MAX_LEN=$len
done <<< "$PROCLIST"

NAME_PADDING=$(( NAME_MAX_LEN * 7 ))
BAR_COUNT=$(echo "$PROCLIST" | wc -l)

if (( BAR_COUNT <= 3 )); then
    BAR_WIDTH=90
    BAR_GAP=60
elif (( BAR_COUNT <= 6 )); then
    BAR_WIDTH=70
    BAR_GAP=50
elif (( BAR_COUNT <= 10 )); then
    BAR_WIDTH=55
    BAR_GAP=40
else
    BAR_WIDTH=45
    BAR_GAP=35
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

MAX_PROC_COUNT=$TPC
(( MAX_PROC_COUNT == 0 )) && MAX_PROC_COUNT=1

echo "<div class='svgbox'><svg width='$SVG_WIDTH' height='$SVG_HEIGHT'>" >> "$HTML_REPORT"

Y_STEP=$(( MAX_PROC_COUNT / 4 ))
(( Y_STEP == 0 )) && Y_STEP=1

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

    echo "<rect x='$X' y='$Y' width='$BAR_WIDTH' height='$h' fill='$COLOR'
    onmouseover=\"this.style.fill='#0079FF';this.style.filter='drop-shadow(0 -4px 6px rgba(0,121,255,0.35))';\"
    onmouseout=\"this.style.fill='$COLOR';this.style.filter='none';\" />" >> "$HTML_REPORT"

    echo "<text x='$((X+8))' y='$((Y-10))'>$ct</text>" >> "$HTML_REPORT"
    echo "<text x='$((X + BAR_WIDTH/2))' y='$((BASELINE+32))' text-anchor='middle' font-size='12'>$short_pr</text>" >> "$HTML_REPORT"

    X=$(( X + BAR_WIDTH + BAR_GAP ))
done <<< "$PROCLIST"

echo "</svg></div>" >> "$HTML_REPORT"
echo "<h2>6. 종합 네트워크 상태 분석</h2>" >> "$HTML_REPORT"
echo "<div class='section'>" >> "$HTML_REPORT"

OPEN_PORTS=$PC
DANGER_OPEN=$(printf "%s\n" "${DANGER_STATUS[@]}" | grep -c "사용 중")
COUNTRY_TOTAL=$CT
SESSION_TOTAL=$EC
PROC_MAX=$TPC

W_PORT=0
W_DANGER=0
W_SESS=0
W_COUNTRY=0
W_PROC=0

(( OPEN_PORTS > 200 )) && W_PORT=1
(( DANGER_OPEN >= 1 )) && W_DANGER=2
(( SESSION_TOTAL >= 300 )) && W_SESS=1
(( COUNTRY_TOTAL >= 8 )) && W_COUNTRY=1
(( PROC_MAX >= 400 )) && W_PROC=1

RISK=$((W_PORT + W_DANGER + W_SESS + W_COUNTRY + W_PROC))

if (( RISK == 0 )); then
    FINAL="모든 지표가 안정적입니다. 매우 좋은 네트워크 상태입니다."
    COLOR="#0079FF"
elif (( RISK == 1 )); then
    FINAL="일부 항목에서 부하가 있으나 전반적으로 정상적인 상태입니다."
    COLOR="#0079FF"
elif (( RISK == 2 )); then
    FINAL="여러 요소에서 주의가 필요합니다. 상세 확인을 권장합니다."
    COLOR="#C44"
else
    FINAL="다수의 위험 요소가 감지되었습니다. 즉각적인 점검이 필요합니다."
    COLOR="#C44"
fi

echo "<div class='comment' style='border-left-color:$COLOR;'>$FINAL</div>" >> "$HTML_REPORT"

TOTAL_UNIQ_PORTS=$(netstat -an | grep -E "LISTEN|ESTABLISHED" | awk '{print $4}' | tr -d '[]' | awk -F'[.:]' '{print $NF}' | grep -E '^[0-9]+$' | sort -n | uniq | wc -l)
(( TOTAL_UNIQ_PORTS == 0 )) && TOTAL_UNIQ_PORTS=1
OPEN_PCT=$(( OPEN_PORTS * 100 / TOTAL_UNIQ_PORTS ))

DANGER_PCT=$(( DANGER_OPEN * 100 / ${#DANGER_PORTS[@]} ))
PORT_ARC=$(( 377 * OPEN_PORTS / TOTAL_UNIQ_PORTS ))
DANGER_ARC=$(( 377 * DANGER_OPEN / ${#DANGER_PORTS[@]} ))


TOTAL_SOCKETS=$(lsof -i | wc -l | tr -d ' ')
TOTAL_SESSIONS=$EC
PROC_MAX=$TPC

if (( TOTAL_SOCKETS == 0 )); then TOTAL_SOCKETS=1; fi

SESS_PCT=$(( TOTAL_SESSIONS * 100 / TOTAL_SOCKETS ))
PROC_PCT=$(( PROC_MAX * 100 / TOTAL_SOCKETS ))

SESS_ARC=$(( 377 * TOTAL_SESSIONS / TOTAL_SOCKETS ))
PROC_ARC=$(( 377 * PROC_MAX / TOTAL_SOCKETS ))

echo "<table>" >> "$HTML_REPORT"
echo "<tr><th>항목</th><th>값</th><th>설명</th></tr>" >> "$HTML_REPORT"
echo "<tr><td>총 소켓 수</td><td>${TOTAL_SOCKETS}개</td><td>현재 시스템 전체 lsof -i 결과</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>ESTABLISHED 세션 수</td><td>${TOTAL_SESSIONS}개</td><td>활성 연결 세션 (핵심 지표)</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>최대 소켓 사용 프로세스</td><td>${PROC_MAX}개</td><td>단일 프로세스가 보유한 소켓 수</td></tr>" >> "$HTML_REPORT"
echo "</table><br>" >> "$HTML_REPORT"

echo "<div style='display:flex; gap:22px; flex-wrap:wrap; justify-content:center;'>" >> "$HTML_REPORT"

echo "<div style='width:160px; height:160px; position:relative;'>" >> "$HTML_REPORT"
echo "<svg width='160' height='160'>" >> "$HTML_REPORT"
echo "<circle cx='80' cy='80' r='65' stroke='#E5E8F0' stroke-width='14' fill='none'/>" >> "$HTML_REPORT"
echo "<circle cx='80' cy='80' r='65' stroke='#0079FF' stroke-width='14' fill='none' stroke-dasharray='${SESS_ARC},377' stroke-linecap='round' transform='rotate(-90 80 80)'/>" >> "$HTML_REPORT"
echo "</svg>" >> "$HTML_REPORT"
echo "<div style='position:absolute; top:48%; left:50%; transform:translate(-50%,-50%); text-align:center; font-size:1rem; font-weight:600;'>SESS ${SESS_PCT}%<br><span style='font-size:0.75rem;'>${TOTAL_SESSIONS}/${TOTAL_SOCKETS}</span></div>" >> "$HTML_REPORT"
echo "</div>" >> "$HTML_REPORT"

echo "<div style='width:160px; height:160px; position:relative;'>" >> "$HTML_REPORT"
echo "<svg width='160' height='160'>" >> "$HTML_REPORT"
echo "<circle cx='80' cy='80' r='65' stroke='#E5E8F0' stroke-width='14' fill='none'/>" >> "$HTML_REPORT"
echo "<circle cx='80' cy='80' r='65' stroke='#0079FF' stroke-width='14' fill='none' stroke-dasharray='${PROC_ARC},377' stroke-linecap='round' transform='rotate(-90 80 80)'/>" >> "$HTML_REPORT"
echo "</svg>" >> "$HTML_REPORT"
echo "<div style='position:absolute; top:48%; left:50%; transform:translate(-50%,-50%); text-align:center; font-size:1rem; font-weight:600;'>PROC ${PROC_PCT}%<br><span style='font-size:0.75rem;'>${PROC_MAX}/${TOTAL_SOCKETS}</span></div>" >> "$HTML_REPORT"
echo "</div>" >> "$HTML_REPORT"

echo "</div></div>" >> "$HTML_REPORT"

echo "<h2>8. 네트워크 상태 평가 기준표</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table><thead><tr><th>항목</th><th>단계</th><th>기준</th></tr></thead><tbody>" >> "$HTML_REPORT"

row() {
    if [ -n "$1" ]; then
        echo "<tr class='active-row'><td>$2</td><td>$3</td><td>$4</td></tr>" >> "$HTML_REPORT"
    else
        echo "<tr><td>$2</td><td>$3</td><td>$4</td></tr>" >> "$HTML_REPORT"
    fi
}

sess_high=$(awk -v e="$SESSION_TOTAL" 'BEGIN{print(e>=300)}')
sess_mid=$(awk -v e="$SESSION_TOTAL" 'BEGIN{print(e>=100 && e<300)}')
sess_low=$(awk -v e="$SESSION_TOTAL" 'BEGIN{print(e<100)}')

danger_flag=$(( DANGER_OPEN >= 1 ? 1 : 0 ))
danger_safe=$(( DANGER_OPEN == 0 ? 1 : 0 ))

country_high=$(awk -v c="$COUNTRY_TOTAL" 'BEGIN{print(c>=8)}')
country_mid=$(awk -v c="$COUNTRY_TOTAL" 'BEGIN{print(c>=3 && c<8)}')
country_low=$(awk -v c="$COUNTRY_TOTAL" 'BEGIN{print(c<3)}')

proc_high=$(awk -v p="$PROC_MAX" 'BEGIN{print(p>=400)}')
proc_mid=$(awk -v p="$PROC_MAX" 'BEGIN{print(p>=100 && p<400)}')
proc_low=$(awk -v p="$PROC_MAX" 'BEGIN{print(p<100)}')

row "$([[ "$sess_high" -eq 1 ]] && echo 1)" "ESTABLISHED 세션" "높음" "300 이상"
row "$([[ "$sess_mid" -eq 1 ]] && echo 1)" "ESTABLISHED 세션" "중간" "100~299"
row "$([[ "$sess_low" -eq 1 ]] && echo 1)" "ESTABLISHED 세션" "낮음" "100 미만"

row "$([[ "$danger_flag" -eq 1 ]] && echo 1)" "위험 포트" "열림" "1개 이상"
row "$([[ "$danger_safe" -eq 1 ]] && echo 1)" "위험 포트" "안전" "모두 닫힘"

row "$([[ "$country_high" -eq 1 ]] && echo 1)" "통신 국가 수" "과다" "8개 이상"
row "$([[ "$country_mid" -eq 1 ]] && echo 1)" "통신 국가 수" "보통" "3~7개"
row "$([[ "$country_low" -eq 1 ]] && echo 1)" "통신 국가 수" "적음" "3개 미만"

row "$([[ "$proc_high" -eq 1 ]] && echo 1)" "프로세스 소켓 수" "매우 높음" "400 이상"
row "$([[ "$proc_mid" -eq 1 ]] && echo 1)" "프로세스 소켓 수" "중간" "100~399"
row "$([[ "$proc_low" -eq 1 ]] && echo 1)" "프로세스 소켓 수" "낮음" "100 미만"

echo "</tbody></table></div></div>" >> "$HTML_REPORT"
echo "</body></html>" >> "$HTML_REPORT"

if command -v open >/dev/null 2>&1; then
    open "$HTML_REPORT"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$HTML_REPORT"
fi

echo "HTML Report saved to: $HTML_REPORT"
echo "Done."
