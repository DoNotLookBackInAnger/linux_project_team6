#!/bin/bash

# 기능 3. 디스크/메모리 사용량 분석

REPORT_DIR="reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/storage_$TIMESTAMP.txt"

# 상위 N개 디렉터리 개수 (기본 5개)
TOP_N=${1:-5}


mkdir -p "$REPORT_DIR"

{
    echo "============================================"
    echo "      기능 3. 디스크/메모리 사용량 분석       "
    echo "   생성 시각: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "============================================"
    echo ""

    echo "1) 파일시스템 전체 용량"
    echo "--------------------------------------------"
    df -h
    echo ""

    echo "2) 디스크 사용률 80% 이상 파일시스템"
    echo "--------------------------------------------"
    HIGH_USAGE=$(df -hP | awk 'NR>1 {gsub("%","",$5); if ($5+0 >= 80) print}')
    if [[ -n "$HIGH_USAGE" ]]; then
        echo "80% 이상 사용 중인 파일시스템:"
        df -hP | head -n 1
        echo "$HIGH_USAGE"
    else
        echo "80% 이상 사용 중인 파일시스템이 없습니다."
    fi
    echo ""

    echo "3) 시스템 상위 ${TOP_N}개의 대용량 디렉터리"
    echo "--------------------------------------------"
    du -x -h /* 2>/dev/null | sort -h -r | head -n "$TOP_N"
    echo ""

    echo "4) 메모리 상태"
    echo "--------------------------------------------"
    if [[ "$OSTYPE" == "darwin"* ]]; then # macOS 확인
        echo "RAM 사용량:"
        top -l 1 | grep PhysMem # macOS 용
        echo ""
        echo "Swap 사용량:"
        sysctl vm.swapusage # macOS 용
    else
        free -h
    fi
    echo ""
} > "$REPORT_FILE"

echo "디스크/메모리 분석 완료"
echo "리포트: $REPORT_FILE"

