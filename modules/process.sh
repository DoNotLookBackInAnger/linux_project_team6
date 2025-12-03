#!/bin/bash

# 기능 4. 프로세스 / CPU 사용량 분석

REPORT_DIR="reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/process_$TIMESTAMP.txt"

# 상위 몇 개까지 볼지 (기본 10개)
TOP_N=${1:-10}

mkdir -p "$REPORT_DIR"

{
    echo "============================================"
    echo "   기능 4. 프로세스 / CPU 사용량 분석 보고서   "
    echo "   생성 시각: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "============================================"
    echo ""

    echo "1) 시스템 부하 및 프로세스 개요"
    echo "--------------------------------------------"
    echo "- uptime (로드 에버리지)"
    uptime
    echo ""
    echo "- 전체 프로세스 수 (ps aux | wc -l)"
    TOTAL_PROC=$(ps aux | wc -l)
    echo "총 프로세스 수: $TOTAL_PROC"
    echo ""

    echo "2) CPU 사용량 상위 ${TOP_N}개 프로세스"
    echo "   (ps aux | sort -nrk 3 | head -n $TOP_N)"
    echo "--------------------------------------------"
    # 헤더 출력
    ps aux | head -n 1
    # CPU 사용률(%CPU, 3번째 컬럼) 기준 내림차순 정렬 후 상위 N개
    ps aux | awk 'NR>1' | sort -nrk 3 | head -n "$TOP_N"
    echo ""

    echo "3) 메모리 사용량 상위 ${TOP_N}개 프로세스"
    echo "   (ps aux | sort -nrk 4 | head -n $TOP_N)"
    echo "--------------------------------------------"
    # 헤더 출력
    ps aux | head -n 1
    # 메모리 사용률(%MEM, 4번째 컬럼) 기준 내림차순 정렬 후 상위 N개
    ps aux | awk 'NR>1' | sort -nrk 4 | head -n "$TOP_N"
    echo ""

    echo "4) 상태별 프로세스 개수 (ps aux | awk)"
    echo "--------------------------------------------"
    # ps AUX의 STAT 컬럼에서 첫 글자 기준으로 상태 집계
    ps aux | awk 'NR>1 {state=substr($8,1,1); count[state]++} END {for (s in count) printf "상태 %s: %d개\n", s, count[s]}'
    echo ""

} > "$REPORT_FILE"

echo "📄 프로세스/CPU 분석 보고서 생성 완료"
echo "➡ $REPORT_FILE"
