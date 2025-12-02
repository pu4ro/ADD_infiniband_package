#!/bin/bash
# ==============================================================================
# Lustre & InfiniBand 초기화 스크립트
# ==============================================================================
# 이 스크립트는 InfiniBand와 Lustre 모듈을 로드하고 LNet을 설정합니다.
# 마운트는 /etc/fstab에 정의된 항목을 통해 mount -a로 처리됩니다.
# systemd 서비스로 사용됩니다.
# ==============================================================================

set -e

# --- 설정 파일 경로 ---
LNET_CONFIG_FILE="/etc/lustre/lnetctl.conf"

# --- 색상 변수 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 로그 함수 ---
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    logger -t lustre-mount "[INFO] $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    logger -t lustre-mount "[WARN] $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    logger -t lustre-mount "[ERROR] $1"
}

# --- InfiniBand 모듈 로드 ---
load_infiniband() {
    log_info "InfiniBand 모듈을 로드합니다..."

    # OFED 드라이버 시작
    if systemctl is-active --quiet openibd; then
        log_info "openibd 서비스가 이미 실행 중입니다."
    else
        log_info "openibd 서비스를 시작합니다..."
        systemctl start openibd || /etc/init.d/openibd start
    fi

    # 주요 InfiniBand 모듈 로드
    local ib_modules="ib_core ib_uverbs ib_umad rdma_cm rdma_ucm mlx5_core mlx5_ib"
    for mod in $ib_modules; do
        if lsmod | grep -q "^$mod"; then
            log_info "모듈 $mod 이미 로드됨"
        else
            log_info "모듈 $mod 로드 중..."
            modprobe $mod 2>/dev/null || log_warn "모듈 $mod 로드 실패 (무시됨)"
        fi
    done

    # InfiniBand 장치 확인
    if [ -d "/sys/class/infiniband" ] && [ -n "$(ls -A /sys/class/infiniband 2>/dev/null)" ]; then
        log_info "InfiniBand 장치 감지됨:"
        ls /sys/class/infiniband
    else
        log_warn "InfiniBand 장치를 찾을 수 없습니다."
    fi
}

# --- LNet 모듈 로드 및 설정 ---
load_lnet() {
    log_info "LNet 모듈을 로드합니다..."

    # LNet 모듈 로드
    if lsmod | grep -q "^lnet"; then
        log_info "lnet 모듈이 이미 로드되어 있습니다."
    else
        log_info "lnet 모듈 로드 중..."
        modprobe lnet
    fi

    # LNet 초기화
    log_info "LNet을 초기화합니다..."
    lnetctl lnet configure

    # LNet 설정 파일 적용
    if [ -f "$LNET_CONFIG_FILE" ]; then
        log_info "LNet 설정 파일 적용: $LNET_CONFIG_FILE"
        lnetctl import "$LNET_CONFIG_FILE"
        log_info "LNet 설정 적용 완료 (o2ib 설정 포함)"
    else
        log_warn "LNet 설정 파일을 찾을 수 없습니다: $LNET_CONFIG_FILE"
        log_warn "기본 LNet 설정으로 진행합니다."
    fi

    # LNet 상태 확인
    log_info "LNet 상태:"
    lnetctl net show 2>/dev/null || log_warn "LNet 네트워크 정보 조회 실패"
}

# --- Lustre 모듈 로드 ---
load_lustre() {
    log_info "Lustre 클라이언트 모듈을 로드합니다..."

    # Lustre 클라이언트 모듈 로드
    local lustre_modules="ksocklnd ko2iblnd ptlrpc obdclass osc lov llite"
    for mod in $lustre_modules; do
        if lsmod | grep -q "^$mod"; then
            log_info "모듈 $mod 이미 로드됨"
        else
            log_info "모듈 $mod 로드 중..."
            modprobe $mod 2>/dev/null || log_warn "모듈 $mod 로드 실패 (무시됨)"
        fi
    done
}

# --- fstab 기반 마운트 ---
mount_lustre() {
    log_info "/etc/fstab에 정의된 Lustre 파일시스템을 마운트합니다..."

    # fstab에 lustre 타입 항목이 있는지 확인
    if grep -q "^[^#].*lustre" /etc/fstab; then
        log_info "fstab에서 Lustre 항목을 발견했습니다."
        mount -a -t lustre
        log_info "Lustre 마운트 완료"
    else
        log_warn "fstab에 Lustre 마운트 항목이 없습니다."
        log_warn "/etc/fstab에 Lustre 파일시스템을 추가하세요."
    fi
}

# --- Lustre 언마운트 ---
umount_lustre() {
    log_info "Lustre 파일시스템을 언마운트합니다..."

    # lustre 타입의 모든 마운트 해제
    local lustre_mounts=$(mount | grep "type lustre" | awk '{print $3}')

    if [ -n "$lustre_mounts" ]; then
        echo "$lustre_mounts" | while read mount_point; do
            log_info "언마운트 중: $mount_point"
            umount "$mount_point"
        done
        log_info "Lustre 언마운트 완료"
    else
        log_info "마운트된 Lustre 파일시스템이 없습니다."
    fi
}

# --- LNet 설정 해제 ---
unconfigure_lnet() {
    log_info "LNet 설정을 해제합니다..."
    lnetctl lnet unconfigure 2>/dev/null || log_warn "LNet unconfigure 실패 (무시됨)"
}

# --- Lustre 모듈 언로드 ---
unload_lustre() {
    log_info "Lustre 모듈을 언로드합니다..."

    # 역순으로 언로드
    local lustre_modules="llite lov osc obdclass ptlrpc ko2iblnd ksocklnd lnet"
    for mod in $lustre_modules; do
        if lsmod | grep -q "^$mod"; then
            log_info "모듈 $mod 언로드 중..."
            rmmod $mod 2>/dev/null || log_warn "모듈 $mod 언로드 실패 (무시됨)"
        fi
    done
}

# --- 상태 확인 ---
status_check() {
    echo "=== Lustre & InfiniBand 상태 ==="
    echo ""

    echo "InfiniBand 장치:"
    if [ -d "/sys/class/infiniband" ]; then
        ls /sys/class/infiniband 2>/dev/null || echo "  없음"
    else
        echo "  없음"
    fi
    echo ""

    echo "LNet 상태:"
    if lsmod | grep -q "^lnet"; then
        echo "  로드됨"
        lnetctl net show 2>/dev/null || echo "  설정 안됨"
    else
        echo "  로드 안됨"
    fi
    echo ""

    echo "Lustre 모듈:"
    if lsmod | grep -q llite; then
        echo "  로드됨"
    else
        echo "  로드 안됨"
    fi
    echo ""

    echo "Lustre 마운트 상태:"
    local lustre_mounts=$(mount | grep "type lustre")
    if [ -n "$lustre_mounts" ]; then
        echo "$lustre_mounts"
    else
        echo "  마운트 안됨"
    fi
}

# --- 메인 실행 ---
case "$1" in
    start)
        log_info "Lustre & InfiniBand 서비스 시작..."
        load_infiniband
        load_lnet
        load_lustre
        mount_lustre
        log_info "서비스 시작 완료"
        ;;
    stop)
        log_info "Lustre & InfiniBand 서비스 중지..."
        umount_lustre
        unconfigure_lnet
        unload_lustre
        log_info "서비스 중지 완료"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        status_check
        ;;
    *)
        echo "사용법: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
