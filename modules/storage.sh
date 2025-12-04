#!/usr/bin/env bash

REPORT_DIR="./reports"
HTML="$REPORT_DIR/storage_report.html"
mkdir -p "$REPORT_DIR"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
host=$(hostname)
TOP_N=${1:-5}

get_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then echo "mac"; else echo "linux"; fi
}
OS=$(get_os)

convert_mb() {
    v=$1
    case "$v" in
        *K) echo $(( ${v%K} / 1024 )) ;;
        *M) echo ${v%M} ;;
        *G) echo $(( ${v%G} * 1024 )) ;;
        *T) echo $(( ${v%T} * 1024 * 1024 )) ;;
        *) echo 0 ;;
    esac
}

if [[ "$OS" == "mac" ]]; then
    FS_RAW=$(df -hP)
    FS_INFO=$(echo "$FS_RAW" | awk 'NR>1 {print}')

    APFS_CONTAINER=$(df -k /System/Volumes/Data | awk 'NR==2 {print $1}')
    APFS_INFO=$(df -k "$APFS_CONTAINER" | awk 'NR==2')

    disk_total_k=$(echo "$APFS_INFO" | awk '{print $2}')
    disk_used_k=$(echo "$APFS_INFO" | awk '{print $3}')
    disk_free_k=$(echo "$APFS_INFO" | awk '{print $4}')

    disk_total_mb=$((disk_total_k / 1024))
    disk_used_mb=$((disk_used_k / 1024))
    disk_free_mb=$((disk_free_k / 1024))

    disk_used_pct=$(printf "%.1f" "$(echo "$disk_used_k $disk_total_k" | awk '{print ($1/$2)*100}')")

    total_ram_bytes=$(sysctl -n hw.memsize)
    TOTAL_RAM_MB=$((total_ram_bytes / 1024 / 1024))

    PHYS=$(vm_stat)
    pagesize=$(echo "$PHYS" | awk 'NR==1 {gsub("\\.","",$8); print $8}')

    active=$(echo "$PHYS" | awk '/Pages active/ {gsub("\\.","",$NF); print $NF; exit}')
    wired=$(echo "$PHYS" | awk '/Pages wired/ {gsub("\\.","",$NF); print $NF; exit}')
    compressed=$(echo "$PHYS" | awk '/Pages occupied by compressor/ {gsub("\\.","",$NF); print $NF; exit}')
    inactive=$(echo "$PHYS" | awk '/Pages inactive:/ {gsub("\\.","",$NF); print $NF; exit}')
    free=$(echo "$PHYS" | awk '/Pages free/ {gsub("\\.","",$NF); print $NF; exit}')

    used_pages=$((active + wired + compressed))
    free_pages=$((inactive + free))

    RAM_USED_MB=$((used_pages * pagesize / 1024 / 1024))
    RAM_FREE_MB=$((free_pages * pagesize / 1024 / 1024))

    RAM_USED=$(printf "%.1f GB" "$(echo "$RAM_USED_MB" | awk '{print $1/1024}')")
    RAM_FREE=$(printf "%.1f GB" "$(echo "$RAM_FREE_MB" | awk '{print $1/1024}')")

    SWAP_USAGE=$(sysctl vm.swapusage | sed 's/^.*: //')

    DIR_RAW=$(du -x -k /* 2>/dev/null | sort -nr | head -n "$TOP_N")
    DIR_TOP=$(echo "$DIR_RAW" | while read -r k p; do echo "$((k/1024)) $p"; done)

else
    FS_RAW=$(df -hP)
    FS_INFO=$(echo "$FS_RAW" | awk 'NR>1 {print}')

    disk_total_k=$(df -k --total | awk '/total/ {print $2}')
    disk_used_k=$(df -k --total | awk '/total/ {print $3}')
    disk_free_k=$(df -k --total | awk '/total/ {print $4}')

    disk_total_mb=$((disk_total_k / 1024))
    disk_used_mb=$((disk_used_k / 1024))
    disk_free_mb=$((disk_free_k / 1024))
    disk_used_pct=$(printf "%.1f" "$(echo "$disk_used_k $disk_total_k" | awk '{print ($1/$2)*100}')")

    TOTAL_RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}')
    MA=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    MU=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') - MA ))

    RAM_USED_MB=$((MU / 1024))
    RAM_FREE_MB=$((MA / 1024))

    RAM_USED=$(printf "%.1f GB" "$(echo "$RAM_USED_MB" | awk '{print $1/1024}')")
    RAM_FREE=$(printf "%.1f GB" "$(echo "$RAM_FREE_MB" | awk '{print $1/1024}')")

    SWAP_USAGE=$(free -h | awk 'NR==3{print "Used: "$3", Free: "$4}')

    DIR_RAW=$(du -x -k /* 2>/dev/null | sort -nr | head -n "$TOP_N")
    DIR_TOP=$(echo "$DIR_RAW" | while read -r k p; do echo "$((k/1024)) $p"; done)
fi

ram_pct=$(printf "%.1f" "$(echo "$RAM_USED_MB $TOTAL_RAM_MB" | awk '{print ($1/$2)*100}')")

disk_used_int=$(printf "%.0f" "$disk_used_pct")
ram_pct_int=$(printf "%.0f" "$ram_pct")

if (( disk_used_int >= 90 )); then disk_level=2
elif (( disk_used_int >= 70 )); then disk_level=1
else disk_level=0
fi

if (( ram_pct_int >= 80 )); then ram_level=2
elif (( ram_pct_int >= 50 )); then ram_level=1
else ram_level=0
fi

cpu_arc=$(printf "%.1f" "$(echo "$disk_used_pct * 3.77" | bc -l)")
mem_arc=$(printf "%.1f" "$(echo "$ram_pct * 3.77" | bc -l)")

cat <<EOF > "$HTML"
<html><head>
<meta charset="UTF-8">
<title>디스크 / 메모리 분석 리포트</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
html { font-size:17px; }
body { background:#F5F6F8; color:#1B1E24; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; padding:40px; line-height:1.6; }
h2 { border-bottom:2px solid #E5E8F0; padding-bottom:6px; margin-top:45px; font-size:1.45rem; }
.section { background:#FFFFFF; padding:22px 26px; border-radius:14px; box-shadow:0 4px 16px rgba(0,0,0,0.05); margin-top:26px; }
table { width:100%; border-collapse:collapse; margin-top:12px; }
th,td { border-bottom:1px solid #E5E5EB; padding:13px 12px; font-size:0.90rem; text-align:center; }
th { background:#F3F6FA; color:#0079FF; border-bottom:2px solid #D7DCE3; }
tr:hover { background:#E8F2FF; color:#0079FF; }
.active-row { background:#E9F4FF !important; color:#0079FF !important; font-weight:600; }
.graph { width:150px; height:150px; position:relative; }
.graph svg { position:absolute; top:0; left:0; }
.graph .label { position:absolute; top:50%; left:50%; transform:translate(-50%,-50%); text-align:center; font-size:1.05rem; font-weight:600; }
.comment { background:#F3F6FF; color:#0079FF; padding:16px 18px; border-left:5px solid #0079FF; margin:22px 0; border-radius:8px; font-size:0.90rem; }

@media (prefers-color-scheme: dark) {
    body {
        background:#1A1C1F;
        color:#E5EAF2;
    }
    .section {
        background:#24262B;
        box-shadow:0 4px 14px rgba(0,0,0,0.6);
    }
    th {
        background:#2C3036;
        color:#5EA8FF;
        border-bottom:2px solid #3A3F47;
    }
    td {
        border-bottom:1px solid #3A3F47;
        color:#E5EAF2;
    }
    tr:hover {
        background:#1E2A3A;
        color:#5EA8FF;
    }
    .active-row {
        background:#25344A !important;
        color:#5EA8FF !important;
        font-weight:600;
    }
    .comment {
        background:#1F2633;
        color:#5EA8FF;
        border-left-color:#5EA8FF;
    }
    svg text {
        fill:#E5EAF2 !important;
    }
}
</style>
</head><body>

<h2>1. 전체 디스크 요약 (Disk Summary)</h2>
<div class="section" style="display:flex; gap:24px; flex-wrap:wrap; align-items:center; justify-content:space-between;">
<div style="flex:1 1 260px; min-width:260px;">
<table>
<tr><th>항목</th><th>값</th></tr>
<tr><td>전체 디스크 용량</td><td>${disk_total_mb}MB</td></tr>
<tr><td>사용량</td><td>${disk_used_mb}MB</td></tr>
<tr><td>남은 용량</td><td>${disk_free_mb}MB</td></tr>
<tr><td>사용률</td><td>${disk_used_pct}%</td></tr>
</table>
</div>

<div style="display:flex; justify-content:center; flex:0 0 260px;">
<div class="graph">
<svg width="150" height="150">
<circle cx="75" cy="75" r="60" stroke="#E5E8F0" stroke-width="14" fill="none"/>
<circle cx="75" cy="75" r="60" stroke="#0079FF" stroke-width="14" fill="none" stroke-dasharray="${cpu_arc},377" stroke-linecap="round" transform="rotate(-90 75 75)"/>
</svg>
<div class="label">DISK ${disk_used_pct}%<br><span style="font-size:0.75rem; font-weight:400;">${disk_used_mb}MB / ${disk_total_mb}MB</span></div>
</div>
</div>
</div>

<h2>2. 파일시스템 상세 목록</h2>
<div class="section"><table>
<tr><th>파일시스템</th><th>총용량</th><th>사용량</th><th>여유공간</th><th>사용률</th><th>마운트 위치</th></tr>
EOF

echo "$FS_INFO" | while read -r line; do
    fs=$(echo "$line" | awk '{print $1}')
    s=$(echo "$line" | awk '{print $2}')
    u=$(echo "$line" | awk '{print $3}')
    a=$(echo "$line" | awk '{print $4}')
    p=$(echo "$line" | awk '{print $5}')
    m=$(echo "$line" | awk '{for(i=6;i<=NF;i++)printf "%s ",$i}')
    pct_num=$(echo "$p" | tr -d '%')
    row_class=""
    [[ $pct_num -ge 80 ]] && row_class="active-row"
    echo "<tr class='$row_class'><td>$fs</td><td>$s</td><td>$u</td><td>$a</td><td>$p</td><td>$m</td></tr>" >> "$HTML"
done

cat <<EOF >> "$HTML"
</table></div>

<h2>3. 대용량 디렉터리 TOP ${TOP_N}</h2>
<div class="section"><table>
<tr><th>크기 (MB)</th><th>디렉터리</th></tr>
EOF

echo "$DIR_TOP" | while read -r size dir; do
    echo "<tr><td>${size} MB</td><td>$dir</td></tr>" >> "$HTML"
done

cat <<EOF >> "$HTML"
</table></div>

<h2>4. 메모리 / 스왑 분석</h2>
<div class="section" style="display:flex; gap:24px; flex-wrap:wrap; align-items:center; justify-content:space-between;">

<div style="flex:1 1 260px; min-width:260px;">
<table>
<tr><th>항목</th><th>값</th></tr>
<tr><td>총 RAM 용량</td><td>${TOTAL_RAM_MB}MB</td></tr>
<tr><td>RAM 사용량</td><td>${RAM_USED_MB}MB</td></tr>
<tr><td>RAM 여유량</td><td>${RAM_FREE_MB}MB</td></tr>
<tr><td>RAM 사용률</td><td>${ram_pct}%</td></tr>
<tr><td>Swap 상태</td><td>${SWAP_USAGE}</td></tr>
</table>
</div>

<div style="display:flex; justify-content:center; flex:0 0 260px;">
<div class="graph">
<svg width="150" height="150">
<circle cx="75" cy="75" r="60" stroke="#E5E8F0" stroke-width="14" fill="none"/>
<circle cx="75" cy="75" r="60" stroke="#0079FF" stroke-width="14" fill="none" stroke-dasharray="${mem_arc},377" stroke-linecap="round" transform="rotate(-90 75 75)"/>
</svg>
<div class="label">MEM ${ram_pct}%<br><span style="font-size:0.75rem; font-weight:400;">${RAM_USED_MB}MB / ${TOTAL_RAM_MB}MB</span></div>
</div>
</div>

</div>

EOF

if (( disk_level == 2 )); then disk_msg="위험"
elif (( disk_level == 1 )); then disk_msg="주의"
else disk_msg="정상"
fi

if (( ram_level == 2 )); then ram_msg="위험"
elif (( ram_level == 1 )); then ram_msg="주의"
else ram_msg="정상"
fi

if (( disk_level==0 && ram_level==0 )); then STORAGE_COMMENT="디스크·메모리 모두 안정적입니다."
elif (( disk_level==2 && ram_level==2 )); then STORAGE_COMMENT="디스크·메모리 모두 위험 상태입니다."
elif (( disk_level==2 )); then STORAGE_COMMENT="디스크 사용률이 매우 높습니다."
elif (( ram_level==2 )); then STORAGE_COMMENT="메모리가 부족한 상태입니다."
elif (( disk_level==1 && ram_level==1 )); then STORAGE_COMMENT="디스크·메모리 모두 주의 단계입니다."
elif (( disk_level==1 )); then STORAGE_COMMENT="디스크 사용률이 다소 높습니다."
elif (( ram_level==1 )); then STORAGE_COMMENT="메모리 사용률이 증가하고 있습니다."
else STORAGE_COMMENT="시스템 상태를 확인하세요."
fi

cat <<EOF >> "$HTML"
<h2>5. 디스크·메모리 기준표</h2>
<div class="section">
<table>
<tr><th>항목</th><th>단계</th><th>기준</th></tr>

<tr class="$( [[ "$disk_level" -eq 2 ]] && echo active-row )"><td>디스크</td><td>위험</td><td>90% 이상</td></tr>
<tr class="$( [[ "$disk_level" -eq 1 ]] && echo active-row )"><td>디스크</td><td>주의</td><td>70–89%</td></tr>
<tr class="$( [[ "$disk_level" -eq 0 ]] && echo active-row )"><td>디스크</td><td>정상</td><td>0–69%</td></tr>

<tr class="$( [[ "$ram_level" -eq 2 ]] && echo active-row )"><td>메모리</td><td>위험</td><td>80% 이상</td></tr>
<tr class="$( [[ "$ram_level" -eq 1 ]] && echo active-row )"><td>메모리</td><td>주의</td><td>50–79%</td></tr>
<tr class="$( [[ "$ram_level" -eq 0 ]] && echo active-row )"><td>메모리</td><td>정상</td><td>0–49%</td></tr>
</table>

<div class="comment">${STORAGE_COMMENT}</div>
</div>

</body></html>
EOF

if command -v open >/dev/null 2>&1; then
    open "$HTML"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$HTML"
fi

echo "HTML Report saved to: $HTML"
