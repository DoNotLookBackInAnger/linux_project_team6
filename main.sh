#!/usr/bin/env bash

MODULE_DIR="./modules"

# ===============================
# 0. Bash 4.0 이상 요구사항 검사
# ===============================
check_bash_version() {
    local version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    local major=$(echo "$version" | cut -d. -f1)

    if [[ "$major" -lt 4 ]]; then
        echo "경고: bash 4.0 이상이 필요합니다. 현재 버전: $version"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Homebrew로 최신 bash 설치:"
            echo "    brew install bash"
        fi
        exit 1
    fi
}

# ===============================
# 1. 필수 명령어 의존성 검사
# ===============================
check_dependencies() {
    local missing=()
    local required_commands=("netstat" "lsof" "ping" "top" "ps" "df" "du" "awk" "grep" "sed" "bc" "curl")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "경고: 다음 명령어가 설치되어 있지 않습니다:"
        echo " → ${missing[*]}"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Homebrew를 통해 설치하시겠습니까? (y/n)"
            read -r response
            if [[ "$response" == "y" ]]; then
                for cmd in "${missing[@]}"; do
                    case "$cmd" in
                        bc)
                            echo "[설치] bc"
                            brew install bc
                            ;;
                        netstat)
                            echo "netstat는 macOS 기본 제공입니다."
                            ;;
                        *)
                            echo "$cmd 설치 방법을 확인해야 합니다."
                            ;;
                    esac
                done
            fi
        else
            echo "리눅스 설치 안내:"
            echo "    sudo apt install ${missing[*]}        (Ubuntu/Debian)"
        fi

        exit 1
    fi
}

# ===============================
# 2. 리눅스 netstat 패키지 안내
# ===============================
check_netstat_linux() {
    if [[ "$OSTYPE" != "darwin"* ]] && ! command -v netstat >/dev/null 2>&1; then
        echo "netstat 명령어가 없습니다."
        echo "설치 명령:"
        echo "    sudo apt install net-tools      (Ubuntu/Debian)"
        echo "    sudo yum install net-tools      (CentOS/RHEL)"
        exit 1
    fi
}

# ===============================
# 3. 전체 메뉴
# ===============================
menu() {
    echo "============================================"
    echo " Linux System Team Project – Main Menu"
    echo "============================================"
    echo "1) 네트워크 포트 스캔 (기능1)"
    echo "2) 네트워크 지연시간 분석 (기능2)"
    echo "3) 디스크/메모리 사용량 분석 (기능3)"
    echo "4) 프로세스 분석 (기능4)"
    echo "5) 종료"
    echo "============================================"
    read -rp "번호 선택: " sel
    echo ""
}

# ===============================
# 4. 기능 실행
# ===============================
run_module() {
    case "$1" in
        1)
            bash "$MODULE_DIR/net_port.sh"
            echo "완료: 네트워크 포트 스캔"
            ;;
        2)
            bash "$MODULE_DIR/net_latency.sh"
            echo "완료: 네트워크 지연시간 분석"
            ;;
        3)
            bash "$MODULE_DIR/storage.sh"
            echo "완료: 디스크/메모리 사용량 분석"
            ;;
        4)
            bash "$MODULE_DIR/process.sh"
            echo "완료: 프로세스 분석"
            ;;
        5)
            echo "종료합니다."
            exit 0
            ;;
        *)
            echo "잘못된 입력입니다."
            ;;
    esac
    echo ""
}

# ===============================
# 5. 실행 시작 전 요구사항 검사
# ===============================
check_bash_version
check_dependencies
check_netstat_linux

# ===============================
# 6. 메인 루프
# ===============================
while true; do
    menu
    run_module "$sel"
done
