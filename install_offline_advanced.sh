#!/bin/bash
set -e # 에러 발생 시 즉시 중단

# ==============================================================================
# 오프라인 통합 설치 스크립트
# ==============================================================================
# 이 스크립트는 OFED 드라이버와 Lustre 클라이언트를 오프라인 환경에 설치합니다.
# 1. 로컬 APT 저장소 설정
# 2. 타겟 커널 설치 및 재부팅 (필요 시)
# 3. OFED 드라이버 설치
# 4. Lustre 클라이언트 소스 빌드 및 설치
# ==============================================================================

# --- 전역 변수 및 환경 설정 ---
setup_env() {
    # .env 파일이 있으면 로드 (Makefile 형식 처리)
    if [ -f ".env" ]; then
        # VARIABLE := value 형식을 VARIABLE=value로 변환하고 소스로 로드
        while IFS= read -r line; do
            # 주석과 빈 줄 건너뛰기
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            # := 를 = 로 변환하고 공백 제거
            line=$(echo "$line" | sed 's/:=/=/g' | sed 's/\s*=\s*/=/g' | sed 's/^\s*export\s*//g')
            export "$line"
        done < .env
    fi

    # Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용
    export TARGET_KERNEL=${TARGET_KERNEL:-"5.15.0-25-generic"}
    export DEBS_DIR=${DEBS_DIR:-"debs"}
    export OFED_DIR=${OFED_DIR:-""}

    # DEBS_DIR 절대 경로 변환
    if [[ "${DEBS_DIR}" = /* ]]; then
        DEB_DIR="${DEBS_DIR}"
    else
        DEB_DIR="$(pwd)/${DEBS_DIR}"
    fi

    # 색상 변수
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    # 스크립트가 루트 권한으로 실행되는지 확인
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}오류: 이 스크립트는 sudo 또는 루트 권한으로 실행해야 합니다.${NC}"
        exit 1
    fi
}

# --- 1단계: 로컬 APT 저장소 등록 ---
setup_local_repo() {
    echo -e "${YELLOW}[Step 1] 로컬 APT 저장소 등록 중...${NC}"

    if [ ! -d "$DEB_DIR" ]; then
        echo -e "${RED}오류: '${DEB_DIR}' 폴더를 찾을 수 없습니다.${NC}"
        echo "이 스크립트는 '${DEBS_DIR}' 폴더가 있는 디렉토리 내에서 실행해야 합니다."
        exit 1
    fi

    if [ ! -f "${DEB_DIR}/Packages.gz" ]; then
        echo -e "${RED}오류: '${DEB_DIR}/Packages.gz' 파일을 찾을 수 없습니다.${NC}"
        echo "저장소가 올바르게 빌드되지 않았습니다."
        exit 1
    fi

    # sources.list에 로컬 경로 등록
    echo "deb [trusted=yes] file:${DEB_DIR} ./" | tee /etc/apt/sources.list.d/local-offline.list > /dev/null

    # 패키지 목록 갱신 (로컬 저장소만 사용하도록 강제)
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/local-offline.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

    echo -e "${GREEN}>> 로컬 저장소 등록 완료.${NC}"
}

# --- 2단계: 커널 버전 체크 및 설치 ---
check_and_install_kernel() {
    local current_kernel=$(uname -r)
    echo -e "${YELLOW}[Step 2] 커널 버전 확인: 현재 ${current_kernel} / 목표 ${TARGET_KERNEL}${NC}"

    if [ "$current_kernel" != "$TARGET_KERNEL" ]; then
        echo -e "${YELLOW}>> 목표 커널과 다릅니다. 커널 설치 및 GRUB 설정을 진행합니다.${NC}"

        apt-get install -y --allow-unauthenticated linux-image-${TARGET_KERNEL} linux-headers-${TARGET_KERNEL} linux-modules-${TARGET_KERNEL} linux-modules-extra-${TARGET_KERNEL}

        # GRUB 설정: 메뉴 표시 및 타임아웃 설정
        sed -i 's/GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
        sed -i 's/GRUB_TIMEOUT=0/GRUB_TIMEOUT=10/' /etc/default/grub

        # 새로 설치한 커널을 기본 부팅 옵션으로 설정
        echo -e "${YELLOW}>> TARGET_KERNEL(${TARGET_KERNEL})을 기본 부팅 옵션으로 설정합니다...${NC}"

        # update-grub을 먼저 실행하여 새 커널을 GRUB 메뉴에 등록
        update-grub

        # /boot/grub/grub.cfg에서 TARGET_KERNEL의 메뉴 항목 찾기
        # 메뉴 항목은 "menuentry" 또는 "submenu"로 시작
        local grub_entry=""

        # Advanced options 서브메뉴 안의 커널 항목 찾기
        if grep -q "submenu.*Advanced options" /boot/grub/grub.cfg; then
            # submenu 인덱스 찾기 (보통 1)
            local submenu_index=$(grep -n "^submenu" /boot/grub/grub.cfg | grep "Advanced options" | cut -d: -f1 | head -n1)

            # TARGET_KERNEL 항목의 인덱스 찾기 (submenu 내에서)
            local kernel_index=$(awk "/submenu.*Advanced options/,/^}/" /boot/grub/grub.cfg | \
                                 grep -n "menuentry.*${TARGET_KERNEL}" | head -n1 | cut -d: -f1)

            if [ -n "$kernel_index" ]; then
                # submenu는 보통 마지막 항목이므로 인덱스 계산
                # GRUB 형식: "submenu_index>kernel_index" (인덱스는 0부터 시작)
                kernel_index=$((kernel_index - 1))

                # submenu가 몇 번째인지 확인 (보통 마지막이므로 전체 메뉴 수 - 1)
                local total_menus=$(grep -c "^menuentry\|^submenu" /boot/grub/grub.cfg)
                submenu_index=$((total_menus - 1))

                grub_entry="gnulinux-advanced-$(blkid -s UUID -o value $(df /boot | tail -1 | awk '{print $1}'))>gnulinux-${TARGET_KERNEL}-advanced-$(blkid -s UUID -o value $(df /boot | tail -1 | awk '{print $1}'))"

                echo ">> TARGET_KERNEL의 GRUB 항목을 찾았습니다."
            fi
        fi

        # GRUB_DEFAULT 설정
        sed -i 's/^GRUB_DEFAULT=.*/#GRUB_DEFAULT=/' /etc/default/grub

        if [ -n "$grub_entry" ]; then
            # 정확한 메뉴 항목 ID로 설정
            echo "GRUB_DEFAULT=\"$grub_entry\"" >> /etc/default/grub
            echo -e "${GREEN}>> GRUB_DEFAULT를 TARGET_KERNEL로 설정: $grub_entry${NC}"
        else
            # 못 찾으면 서브메뉴의 첫 번째 항목으로 설정 (일반적으로 가장 최신 커널)
            echo "GRUB_DEFAULT=\"1>0\"" >> /etc/default/grub
            echo -e "${YELLOW}>> GRUB_DEFAULT를 Advanced options의 첫 번째 항목(1>0)으로 설정${NC}"
        fi

        update-grub

        echo -e "${GREEN}>> GRUB 설정 완료: ${TARGET_KERNEL}이 기본 부팅 커널로 설정되었습니다.${NC}"

        echo -e "${RED}======================================================${NC}"
        echo -e "${RED} [중요] 시스템 재부팅이 필요합니다!${NC}"
        echo -e "${RED} 재부팅 시 자동으로 ${TARGET_KERNEL} 커널로 부팅됩니다.${NC}"
        echo -e "${RED} 부팅 후 이 스크립트를 다시 실행하면 설치가 이어집니다.${NC}"
        echo -e "${RED}======================================================${NC}"

        read -p "지금 재부팅 하시겠습니까? (y/n): " REBOOT_NOW
        if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
            reboot
        fi
        exit 0
    fi
    echo -e "${GREEN}>> 커널 버전이 일치합니다. 설치를 계속합니다.${NC}"
}

# --- 4단계: 필수 의존성 및 빌드 도구 설치 ---
install_dependencies() {
    echo -e "${YELLOW}[Step 4] 빌드 도구 및 의존성 설치 중...${NC}"
    apt-get install -y --allow-unauthenticated \
        build-essential dkms bison flex libyaml-dev libreadline-dev \
        libkeyutils-dev libmount-dev libnl-3-dev libnl-route-3-dev \
        libtool automake pkg-config pciutils ethtool lsof \
        lustre-source lustre-client-utils
    echo -e "${GREEN}>> 의존성 설치 완료.${NC}"
}

# --- 3단계: OFED 드라이버 설치 ---
install_ofed() {
    echo -e "${YELLOW}[Step 3] Mellanox OFED 설치 시작...${NC}"

    # bzip2 설치 (OFED 압축 해제에 필요)
    echo -e "${YELLOW}>> bzip2 설치 중...${NC}"
    apt-get install -y --allow-unauthenticated bzip2
    echo -e "${GREEN}>> bzip2 설치 완료.${NC}"

    local ofed_install_dir=""

    # .env에 OFED_DIR이 지정되었는지 확인
    if [ -n "${OFED_DIR}" ] && [ -d "${OFED_DIR}" ]; then
        echo ">> .env에 지정된 OFED 디렉토리 사용: ${OFED_DIR}"
        ofed_install_dir="${OFED_DIR}"
    else
        # 자동 탐지 로직: /root 디렉토리에서 먼저 찾고, 없으면 현재 디렉토리에서 찾기
        echo ">> OFED 디렉토리 자동 탐지 중..."

        # /root 디렉토리에서 OFED 패키지 찾기
        local ofed_tar=$(find /root -maxdepth 1 -name "MLNX_OFED_LINUX-*.tgz" 2>/dev/null | head -n 1)

        # /root에 없으면 현재 디렉토리에서 찾기
        if [ -z "$ofed_tar" ]; then
            ofed_tar=$(find . -maxdepth 1 -name "MLNX_OFED_LINUX-*.tgz" | head -n 1)
        fi

        if [ -f "$ofed_tar" ]; then
            echo "OFED 압축파일 발견: $ofed_tar"
            echo "OFED 압축 해제 중..."
            local extract_dir=$(dirname "$ofed_tar")
            tar -zxf "$ofed_tar" -C "$extract_dir"

            # 압축 해제된 디렉토리 찾기
            ofed_install_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "MLNX_OFED_LINUX-*" | head -n 1)
        else
            # 이미 압축 해제된 디렉토리 찾기
            ofed_install_dir=$(find /root -maxdepth 1 -type d -name "MLNX_OFED_LINUX-*" 2>/dev/null | head -n 1)

            if [ -z "$ofed_install_dir" ]; then
                ofed_install_dir=$(find . -maxdepth 1 -type d -name "MLNX_OFED_LINUX-*" | head -n 1)
            fi
        fi
    fi

    if [ -z "$ofed_install_dir" ] || [ ! -d "$ofed_install_dir" ]; then
        echo -e "${RED}오류: OFED 설치 디렉토리를 찾을 수 없습니다.${NC}"
        echo "다음 중 하나를 확인하세요:"
        echo "  1. '.env' 파일에 OFED_DIR를 정확히 지정"
        echo "  2. /root 디렉토리에 MLNX_OFED_LINUX-*.tgz 파일 존재"
        echo "  3. 현재 디렉토리에 MLNX_OFED_LINUX-*.tgz 파일 존재"
        exit 1
    fi

    echo ">> OFED 설치 디렉토리: $ofed_install_dir"
    (
        cd "$ofed_install_dir"
        echo "OFED 설치 진행... (in $(pwd))"
        ./mlnxofedinstall --add-kernel-support --without-fw-update --force
    )

    echo "OFED 서비스 재시작..."
    /etc/init.d/openibd restart
    echo -e "${GREEN}>> OFED 설치 완료.${NC}"
}

# --- 5단계: Lustre 클라이언트 빌드 및 설치 ---
build_lustre() {
    echo -e "${YELLOW}[Step 5] Lustre Client 소스 빌드 시작...${NC}"

    # lustre로 시작하고 .tar.bz2로 끝나는 파일 찾기
    local lustre_archive=$(find /usr/src -maxdepth 1 -name "lustre*.tar.bz2" | head -n 1)

    if [ -z "$lustre_archive" ]; then
        echo -e "${RED}오류: /usr/src/lustre*.tar.bz2 파일이 없습니다. (lustre-source 설치 실패?)${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Lustre 소스 압축파일: $lustre_archive${NC}"

    (
        cd /usr/src
        # 이전 빌드 잔여물 제거
        find . -maxdepth 1 -type d -name "lustre-*" -exec rm -rf {} + 2>/dev/null || true
        find . -maxdepth 1 -type d -name "modules" -exec rm -rf {} + 2>/dev/null || true

        tar -jxf "$(basename "$lustre_archive")"

        # Lustre 소스 디렉토리 찾기
        local lustre_src_dir=""
        if [ -d "modules/lustre" ]; then
            lustre_src_dir="modules/lustre"
        else
            lustre_src_dir=$(find . -maxdepth 1 -type d -name "lustre-*" | head -n 1)
        fi

        if [ -z "$lustre_src_dir" ]; then
            echo -e "${RED}오류: Lustre 소스 디렉토리를 찾을 수 없습니다.${NC}"
            exit 1
        fi

        cd "$lustre_src_dir"

        echo "Configure 실행 중..."
        ./configure --with-linux=/usr/src/linux-headers-${TARGET_KERNEL} --disable-server

        echo "Make 실행 중 (CPU 코어 수만큼 병렬 빌드)..."
        make -j$(nproc)

        echo "Install 실행 중..."
        make install
    )

    depmod -a
    echo -e "${GREEN}>> Lustre 빌드 및 설치 완료.${NC}"
}

# --- 6단계: 최종 확인 ---
verify_installation() {
    echo -e "${YELLOW}[Step 6] 설치 검증${NC}"
    modprobe lustre

    if lsmod | grep -q lustre; then
        echo -e "${GREEN}===============================================${NC}"
        echo -e "${GREEN}   Lustre 및 OFED 설치가 성공적으로 완료되었습니다!   ${NC}"
        echo -e "${GREEN}===============================================${NC}"
        echo "다음 명령어로 마운트를 테스트하세요:"
        echo "  mkdir -p /mnt/lustre"
        echo "  mount -t lustre <MGS_NID>:/<FSNAME> /mnt/lustre"
    else
        echo -e "${RED}경고: lustre 모듈이 로드되지 않았습니다. 빌드 로그를 확인하세요.${NC}"
    fi
}

# --- 메인 실행 함수 ---
main() {
    setup_env
    echo -e "${GREEN}=== 오프라인 통합 설치 스크립트 시작 ===${NC}"
    echo "설정:"
    echo "  TARGET_KERNEL = ${TARGET_KERNEL}"
    echo "  DEBS_DIR      = ${DEBS_DIR}"
    echo "  DEB_DIR       = ${DEB_DIR}"
    echo "  OFED_DIR      = ${OFED_DIR}"
    echo ""

    setup_local_repo
    check_and_install_kernel
    install_ofed
    install_dependencies
    build_lustre
    verify_installation

    echo -e "${GREEN}=== 모든 작업 완료 ===${NC}"
}

# 스크립트 실행
main "$@"
