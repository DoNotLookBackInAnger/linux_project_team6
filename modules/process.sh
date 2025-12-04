#!/usr/bin/env bash

REPORT_DIR="./reports"
HTML_REPORT="$REPORT_DIR/process_report.html"
mkdir -p "$REPORT_DIR"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
host=$(hostname)
TOP_N=${1:-10}

get_os_type() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    else
        echo "linux"
    fi
}

OS=$(get_os_type)

if [[ "$OS" == "mac" ]]; then
    LOAD_AVG=$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')

    MEM_TOTAL_BYTES=$(sysctl -n hw.memsize)
    MEM_TOTAL_MB=$((MEM_TOTAL_BYTES / 1024 / 1024))

    VM_STAT=$(vm_stat)
    pagesize=$(echo "$VM_STAT" | awk 'NR==1 {gsub("\\.","",$8); print $8}')
    active=$(echo "$VM_STAT" | awk '/Pages active/ {gsub("\\.","",$NF); print $NF; exit}')
    wired=$(echo "$VM_STAT" | awk '/Pages wired/ {gsub("\\.","",$NF); print $NF; exit}')
    compressed=$(echo "$VM_STAT" | awk '/Pages occupied by compressor/ {gsub("\\.","",$NF); print $NF; exit}')
    inactive=$(echo "$VM_STAT" | awk '/Pages inactive/ {gsub("\\.","",$NF); print $NF; exit}')
    free=$(echo "$VM_STAT" | awk '/Pages free/ {gsub("\\.","",$NF); print $NF; exit}')

    USED_PAGES=$((active + wired + compressed))
    FREE_PAGES=$((inactive + free))

    MEM_USED_MB=$((USED_PAGES * pagesize / 1024 / 1024))
    MEM_FREE_MB=$((FREE_PAGES * pagesize / 1024 / 1024))
    MEM_PCT=$(printf "%.1f" "$(echo "$MEM_USED_MB $MEM_TOTAL_MB" | awk '{print ($1/$2)*100}')")

    CPU_PCT=$(top -l 1 | grep "CPU usage" | awk -F',' '{print $1,$2}' | awk '{u=$3; s=$6; print u+s}')
    CORE_COUNT=$(sysctl -n hw.ncpu)
    CPU_REAL=$(printf "%.1f" "$(echo "$CPU_PCT * $CORE_COUNT / 100" | bc -l)")

    RAW_TOP=$(top -l 2 -o cpu -stats pid,user,cpu,mem,state,time,command | awk '/PID/ {block++} block==2' | awk '$1 ~ /^[0-9]+$/')

    CPU_LIST=""
    MEM_LIST=""

    while read -r line; do
        pid=$(echo "$line" | awk '{print $1}')
        [[ -z "$pid" ]] && continue
        user=$(echo "$line" | awk '{print $2}')
        cpu=$(echo "$line" | awk '{print $3}')
        mem_raw=$(echo "$line" | awk '{print $4}')
        case "$mem_raw" in
            *M) mem=$(echo "${mem_raw%M}") ;;
            *K) mem=$(echo "$(( ${mem_raw%K} / 1024 ))") ;;
            *) mem=0 ;;
        esac
        state=$(echo "$line" | awk '{print $5}')
        time=$(echo "$line" | awk '{print $6}')
        cmd=$(ps -p "$pid" -o comm=)
        CPU_LIST+="$pid $user $cpu $mem $state $time $cmd"$'\n'
        MEM_LIST+="$pid $user $cpu $mem $state $time $cmd"$'\n'
    done <<< "$RAW_TOP"

    CPU_RAW=$(echo "$CPU_LIST" | sort -k3 -nr | head -n "$TOP_N")
    MEM_RAW=$(echo "$MEM_LIST" | sort -k4 -nr | head -n "$TOP_N")

else
    LOAD_AVG=$(awk '{print $1, $2, $3}' /proc/loadavg)
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
    MEM_PCT=$(printf "%.1f" "$(echo "$MEM_USED $MEM_TOTAL" | awk '{print ($1/$2)*100}')")
    MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
    MEM_USED_MB=$((MEM_USED / 1024))

    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
    CPU_PCT=$(printf "%.1f" "$(echo "100 - $CPU_IDLE" | bc)")
    CPU_REAL=$(printf "%.1f" "$CPU_PCT")
    CORE_COUNT=1

    CPU_RAW=$(ps -eo pid,user,%cpu,%mem,state,time,cmd --sort=-%cpu | awk 'NR>1' | head -n "$TOP_N")
    MEM_RAW=$(ps -eo pid,user,%cpu,%mem,state,time,cmd --sort=-%mem | awk 'NR>1' | head -n "$TOP_N")
fi

CPU_ARC=$(printf "%.1f" "$(echo "$CPU_PCT * 3.77" | bc -l)")
MEM_ARC=$(printf "%.1f" "$(echo "$MEM_PCT * 3.77" | bc -l)")

PS_ALL=$(ps -Ao pid,state)
TOTAL_PROC=$(echo "$PS_ALL" | awk 'NR>1 {print $1}' | wc -l)
STATE_COUNTS=$(echo "$PS_ALL" | awk 'NR>1 {s=substr($2,1,1); if(s!="") c[s]++} END{for(k in c) print c[k], k}')
SUM_STATE=$(echo "$STATE_COUNTS" | awk '{x+=$1} END{print x}')

cat <<EOF > "$HTML_REPORT"
<html>
<head>
<meta charset="UTF-8">
<title>프로세스 / CPU 사용량 분석 리포트</title>
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
th,td { border-bottom:1px solid #E5E5EB; padding:13px 12px; font-size:0.90rem; text-align:center; }
th { background:#F3F6FA; color:#0079FF; border-bottom:2px solid #D7DCE3; }
tr:hover { background:#E8F2FF; color:#0079FF; }
.comment { background:#F3F6FF; color:#0079FF; padding:16px 18px; border-left:5px solid #0079FF; margin:22px 0; border-radius:8px; font-size:0.90rem; }
tfoot td { color:#0079FF; font-weight:600; text-align:right; }
td.command { max-width:240px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; cursor:pointer; }
td.command:hover { white-space:normal; overflow:visible; background:#eef5ff; position:relative; z-index:10; word-break:break-all; }
@media (prefers-color-scheme: dark) {
body { background:#1A1C1F; color:#E5EAF2; }
h2 { border-bottom:2px solid #2A2D33; }
.section { background:#24262B; box-shadow:0 4px 14px rgba(0,0,0,0.6); }
th { background:#2C3036; color:#5EA8FF; border-bottom:2px solid #3A3F47; }
td { border-bottom:1px solid #3A3F47; }
tr:hover { background:#1E2A3A; color:#5EA8FF; }
tfoot td { color:#5EA8FF; }
.comment { background:#1F2633; color:#5EA8FF; border-left-color:#5EA8FF; }
td.command:hover { background:#1F2940; word-break:break-all; }
}
.active-row { background:#E9F4FF !important; color:#0079FF !important; font-weight:600; }
@media (prefers-color-scheme: dark) {
.active-row { background:#25344A !important; color:#5EA8FF !important; font-weight:600; }
}
</style>
</head>
<body>

<h1>프로세스 / CPU 사용량 분석 리포트</h1>
<p>호스트: $host<br>생성 시각: $timestamp</p>

<h2>1. 시스템 부하 및 프로세스 개요</h2>
<div class="section" style="display:flex; gap:24px; flex-wrap:wrap; align-items:center; justify-content:space-between;">
<div style="flex:1 1 260px; min-width:260px;">
<table>
<tr><th>항목 (Item)</th><th>값 (Value)</th></tr>
<tr><td>Load Average</td><td>$LOAD_AVG</td></tr>
<tr><td>전체 프로세스 수 (Total Processes)</td><td>$TOTAL_PROC</td></tr>
</table>
</div>

<div style="display:flex; gap:22px; flex-wrap:wrap; justify-content:center; flex:0 0 260px;">

<div style="width:150px; height:150px; position:relative;">
<svg width="150" height="150">
<circle cx="75" cy="75" r="60" stroke="#E5E8F0" stroke-width="14" fill="none"/>
<circle cx="75" cy="75" r="60" stroke="#0079FF" stroke-width="14" fill="none" stroke-dasharray="${CPU_ARC},377" stroke-linecap="round" transform="rotate(-90 75 75)"/>
</svg>
<div style="position:absolute; top:49%; left:50%; transform:translate(-50%,-50%); text-align:center; font-size:1.05rem; font-weight:600;">
CPU ${CPU_PCT}%
<div style="font-size:0.75rem; font-weight:400; margin-top:2px;">${CPU_REAL} / ${CORE_COUNT} Core</div>
</div>
</div>

<div style="width:150px; height:150px; position:relative;">
<svg width="150" height="150">
<circle cx="75" cy="75" r="60" stroke="#E5E8F0" stroke-width="14" fill="none"/>
<circle cx="75" cy="75" r="60" stroke="#0079FF" stroke-width="14" fill="none" stroke-dasharray="${MEM_ARC},377" stroke-linecap="round" transform="rotate(-90 75 75)"/>
</svg>
<div style="position:absolute; top:49%; left:50%; transform:translate(-50%,-50%); text-align:center; font-size:1.05rem; font-weight:600;">
MEM ${MEM_PCT}%
<div style="font-size:0.75rem; font-weight:400; margin-top:2px;">${MEM_USED_MB}MB / ${MEM_TOTAL_MB}MB</div>
</div>
</div>

</div>
</div>

<h2>2. CPU 사용량 상위 ${TOP_N}개 프로세스</h2>
<div class="section">
<table>
<tr>
<th>PID</th><th>사용자 (User)</th><th>CPU 사용률 (%CPU)</th><th>메모리 (MB)</th><th>상태 (State)</th><th>누적 CPU 시간 (Time)</th><th>명령어 (Command)</th>
</tr>
EOF

if [[ "$OS" == "mac" ]]; then
    while read -r pid user cpu mem state time cmd; do
        echo "<tr><td>$pid</td><td>$user</td><td>$cpu</td><td>${mem}MB</td><td>$state</td><td>$time</td><td class='command'>$cmd</td></tr>" >> "$HTML_REPORT"
    done <<< "$CPU_RAW"
else
    while read -r pid user cpu mem state time cmd; do
        echo "<tr><td>$pid</td><td>$user</td><td>$cpu</td><td>${mem}</td><td>$state</td><td>$time</td><td class='command'>$cmd</td></tr>" >> "$HTML_REPORT"
    done <<< "$CPU_RAW"
fi

echo "</table></div>" >> "$HTML_REPORT"

echo "<h2>3. 메모리 사용량 상위 ${TOP_N}개 프로세스</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table><tr><th>PID</th><th>사용자 (User)</th><th>CPU 사용률 (%CPU)</th><th>메모리 (MB)</th><th>상태 (State)</th><th>누적 CPU 시간 (Time)</th><th>명령어 (Command)</th></tr>" >> "$HTML_REPORT"

if [[ "$OS" == "mac" ]]; then
    while read -r pid user cpu mem state time cmd; do
        echo "<tr><td>$pid</td><td>$user</td><td>$cpu</td><td>${mem}MB</td><td>$state</td><td>$time</td><td class='command'>$cmd</td></tr>" >> "$HTML_REPORT"
    done <<< "$MEM_RAW"
else
    while read -r pid user cpu mem state time cmd; do
        echo "<tr><td>$pid</td><td>$user</td><td>$cpu</td><td>${mem}</td><td>$state</td><td>$time</td><td class='command'>$cmd</td></tr>" >> "$HTML_REPORT"
    done <<< "$MEM_RAW"
fi

echo "</table></div>" >> "$HTML_REPORT"

echo "<h2>4. 상태별 프로세스 개수</h2>" >> "$HTML_REPORT"

SLEEP_COUNT=$(echo "$STATE_COUNTS" | awk '$2=="S" {print $1}')
[[ -z "$SLEEP_COUNT" ]] && SLEEP_COUNT=0

SLEEP_PCT=$(printf "%.1f" "$(echo "$SLEEP_COUNT $TOTAL_PROC" | awk '{print ($1/$2)*100}')")
SLEEP_ARC=$(printf "%.1f" "$(echo "$SLEEP_PCT * 3.77" | bc -l)")

echo "<div class='section' style='display:flex; gap:24px; flex-wrap:wrap; align-items:center; justify-content:space-between;'>" >> "$HTML_REPORT"

echo "<div style='flex:1 1 260px; min-width:260px;'>" >> "$HTML_REPORT"
echo "<table>" >> "$HTML_REPORT"
echo "<tr><th>상태 코드 (State)</th><th>개수 (Count)</th></tr>" >> "$HTML_REPORT"

while read -r count state; do
    echo "<tr><td>$state</td><td>$count</td></tr>" >> "$HTML_REPORT"
done <<< "$STATE_COUNTS"

echo "<tfoot><tr><td colspan='2'>총합: $SUM_STATE</td></tr></tfoot></table></div>" >> "$HTML_REPORT"

echo "<div style='display:flex; gap:22px; flex-wrap:wrap; justify-content:center; flex:0 0 260px;'>" >> "$HTML_REPORT"

echo "<div style='width:150px; height:150px; position:relative;'>
<svg width='150' height='150'>
<circle cx='75' cy='75' r='60' stroke='#E5E8F0' stroke-width='14' fill='none'/>
<circle cx='75' cy='75' r='60' stroke='#0079FF' stroke-width='14' fill='none' stroke-dasharray='${SLEEP_ARC},377' stroke-linecap='round' transform='rotate(-90 75 75)'/>
</svg>
<div style='position:absolute; top:49%; left:50%; transform:translate(-50%,-50%); text-align:center; font-size:1.05rem; font-weight:600;'>
Sleeping ${SLEEP_PCT}%
<div style='font-size:0.75rem; font-weight:400; margin-top:2px;'>${SLEEP_COUNT}/${TOTAL_PROC}</div>
</div>
</div>" >> "$HTML_REPORT"

echo "</div></div>" >> "$HTML_REPORT"

echo "<h2>프로세스 상태 코드 기준표</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table>" >> "$HTML_REPORT"
echo "<tr><th>상태 코드 (State)</th><th>의미 (Meaning)</th></tr>" >> "$HTML_REPORT"
echo "<tr><td>R</td><td>Running</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>S</td><td>Sleeping</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>I</td><td>Idle</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>T</td><td>Stopped</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>Z</td><td>Zombie</td></tr>" >> "$HTML_REPORT"
echo "<tr><td>W</td><td>Paging</td></tr></table></div>" >> "$HTML_REPORT"

highlight_mem_danger=$(awk -v m="$MEM_PCT" 'BEGIN{print(m>=80)}')
highlight_mem_warning=$(awk -v m="$MEM_PCT" 'BEGIN{print(m>=50 && m<80)}')
highlight_mem_normal=$(awk -v m="$MEM_PCT" 'BEGIN{print(m<50)}')

highlight_cpu_overload=$(awk -v c="$CPU_PCT" 'BEGIN{print(c>=70)}')
highlight_cpu_busy=$(awk -v c="$CPU_PCT" 'BEGIN{print(c>=40 && c<70)}')
highlight_cpu_normal=$(awk -v c="$CPU_PCT" 'BEGIN{print(c<40)}')

if (( $(echo "$MEM_PCT < 50" | bc -l) )); then
    mem_level=0
elif (( $(echo "$MEM_PCT < 80" | bc -l) )); then
    mem_level=1
else
    mem_level=2
fi

if (( $(echo "$CPU_PCT < 40" | bc -l) )); then
    cpu_level=0
elif (( $(echo "$CPU_PCT < 70" | bc -l) )); then
    cpu_level=1
else
    cpu_level=2
fi

case "$mem_level-$cpu_level" in
    0-0) final_comment="시스템 전체 상태는 매우 안정적입니다." ;;
    0-1) final_comment="메모리는 여유롭지만 CPU 부하가 증가하고 있습니다." ;;
    0-2) final_comment="메모리는 충분하지만 CPU가 과부하 상태입니다." ;;
    1-0) final_comment="메모리가 다소 사용 중이지만 CPU는 안정적입니다." ;;
    1-1) final_comment="메모리와 CPU 모두 주의 단계입니다." ;;
    1-2) final_comment="메모리는 주의 단계이며 CPU는 과부하 상태입니다." ;;
    2-0) final_comment="메모리가 매우 부족하지만 CPU는 안정적입니다." ;;
    2-1) final_comment="메모리는 위험 수준이고 CPU 부하도 증가하고 있습니다." ;;
    2-2) final_comment="CPU·메모리 모두 위험 단계입니다." ;;
esac

echo "<h2>메모리·CPU 사용량 기준표</h2>" >> "$HTML_REPORT"
echo "<div class='section'><table><thead><tr><th>항목</th><th>단계</th><th>기준</th></tr></thead><tbody>" >> "$HTML_REPORT"

row() { echo "<tr class='$1'><td>$2</td><td>$3</td><td>$4</td></tr>" >> "$HTML_REPORT"; }

row "$( [[ "$highlight_mem_danger" -eq 1 ]] && echo active-row )" "메모리" "위험(Danger)" "≥ 80%"
row "$( [[ "$highlight_mem_warning" -eq 1 ]] && echo active-row )" "메모리" "주의(Warning)" "50–79%"
row "$( [[ "$highlight_mem_normal" -eq 1 ]] && echo active-row )" "메모리" "정상(Normal)" "0–49%"

row "$( [[ "$highlight_cpu_overload" -eq 1 ]] && echo active-row )" "CPU" "과부하(Overload)" "≥ 70%"
row "$( [[ "$highlight_cpu_busy" -eq 1 ]] && echo active-row )" "CPU" "주의(Busy)" "40–69%"
row "$( [[ "$highlight_cpu_normal" -eq 1 ]] && echo active-row )" "CPU" "정상(Normal)" "0–39%"

echo "</tbody></table>" >> "$HTML_REPORT"
echo "<div class='comment'>$final_comment</div></div>" >> "$HTML_REPORT"
echo "</body></html>" >> "$HTML_REPORT"

if command -v open >/dev/null 2>&1; then
    open "$HTML_REPORT"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$HTML_REPORT"
fi

echo "HTML Report saved to: $HTML_REPORT"
echo "Done."
