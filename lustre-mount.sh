#!/bin/bash
# ==============================================================================
# Lustre & InfiniBand 초기화 및 마운트 스크립트
# ==============================================================================
# 이 스크립트는 InfiniBand와 Lustre 모듈을 로드하고 Lustre 파일시스템을 마운트합니다.
# systemd 서비스로 사용됩니다.
# ==============================================================================

set -e

# --- 설정 파일 로드 ---
CONFIG_FILE="/etc/lustre-mount.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "오류: 설정 파일 $CONFIG_FILE 을 찾을 수 없습니다."
    exit 1
fi

# 필수 변수 확인
if [ -z "$LUSTRE_MGS" ] || [ -z "$LUSTRE_FSNAME" ] || [ -z "$LUSTRE_MOUNT_POINT" ]; then
    echo "오류: 설정 파일에 필수 변수가 누락되었습니다."
    echo "LUSTRE_MGS, LUSTRE_FSNAME, LUSTRE_MOUNT_POINT를 설정하세요."
    exit 1
fi

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

# --- Lustre 모듈 로드 ---
load_lustre() {
    log_info "Lustre 모듈을 로드합니다..."

    # Lustre 관련 모듈 로드
    local lustre_modules="libcfs lnet ksocklnd ko2iblnd ptlrpc obdclass osc lov llite"
    for mod in $lustre_modules; do
        if lsmod | grep -q "^$mod"; then
            log_info "모듈 $mod 이미 로드됨"
        else
            log_info "모듈 $mod 로드 중..."
            modprobe $mod 2>/dev/null || log_warn "모듈 $mod 로드 실패 (무시됨)"
        fi
    done

    # LNet 네트워크 시작
    if lsmod | grep -q "^lnet"; then
        log_info "LNet 네트워크 설정 확인..."
        lctl network up 2>/dev/null || log_warn "LNet 네트워크 이미 활성화됨"
    fi
}

# --- Lustre 마운트 ---
mount_lustre() {
    log_info "Lustre 파일시스템 마운트 준비..."

    # 마운트 포인트 생성
    if [ ! -d "$LUSTRE_MOUNT_POINT" ]; then
        log_info "마운트 포인트 생성: $LUSTRE_MOUNT_POINT"
        mkdir -p "$LUSTRE_MOUNT_POINT"
    fi

    # 이미 마운트되어 있는지 확인
    if mountpoint -q "$LUSTRE_MOUNT_POINT"; then
        log_info "Lustre가 이미 마운트되어 있습니다: $LUSTRE_MOUNT_POINT"
        return 0
    fi

    # Lustre 마운트
    log_info "Lustre 마운트 중: ${LUSTRE_MGS}:/${LUSTRE_FSNAME} -> $LUSTRE_MOUNT_POINT"
    if mount -t lustre "${LUSTRE_MGS}:/${LUSTRE_FSNAME}" "$LUSTRE_MOUNT_POINT"; then
        log_info "Lustre 마운트 성공!"
    else
        log_error "Lustre 마운트 실패!"
        return 1
    fi
}

# --- Lustre 언마운트 ---
umount_lustre() {
    log_info "Lustre 파일시스템 언마운트 중..."

    if mountpoint -q "$LUSTRE_MOUNT_POINT"; then
        umount "$LUSTRE_MOUNT_POINT"
        log_info "Lustre 언마운트 완료"
    else
        log_info "Lustre가 마운트되어 있지 않습니다."
    fi
}

# --- Lustre 모듈 언로드 ---
unload_lustre() {
    log_info "Lustre 모듈을 언로드합니다..."

    # 역순으로 언로드
    local lustre_modules="llite lov osc obdclass ptlrpc ko2iblnd ksocklnd lnet libcfs"
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

    echo "Lustre 모듈:"
    if lsmod | grep -q lustre; then
        echo "  로드됨"
    else
        echo "  로드 안됨"
    fi
    echo ""

    echo "마운트 상태:"
    if mountpoint -q "$LUSTRE_MOUNT_POINT"; then
        echo "  마운트됨: $LUSTRE_MOUNT_POINT"
        df -h "$LUSTRE_MOUNT_POINT"
    else
        echo "  마운트 안됨"
    fi
}

# --- 메인 실행 ---
case "$1" in
    start)
        log_info "Lustre & InfiniBand 서비스 시작..."
        load_infiniband
        load_lustre
        mount_lustre
        log_info "서비스 시작 완료"
        ;;
    stop)
        log_info "Lustre & InfiniBand 서비스 중지..."
        umount_lustre
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
