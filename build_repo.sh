#!/bin/bash
set -e

# ==============================================================================
# 온라인 저장소 빌드 스크립트
# ==============================================================================
# 이 스크립트는 온라인 환경에서 다음 작업을 수행합니다:
# 1. 필요한 패키지 의존성 다운로드
# 2. 로컬 APT 저장소 생성 (Packages.gz)
# 3. 오프라인 배포용 아카이브 생성 (선택사항)
# ==============================================================================

# --- 환경 변수 설정 ---
TARGET_KERNEL=${TARGET_KERNEL:-"5.15.0-25-generic"}
DEBS_DIR=${DEBS_DIR:-"debs"}
ARCHIVE_NAME=${ARCHIVE_NAME:-"offline_kit.tar.gz"}

# 색상 변수
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 온라인 저장소 빌드 스크립트 시작 ===${NC}"
echo "설정:"
echo "  TARGET_KERNEL  = ${TARGET_KERNEL}"
echo "  DEBS_DIR       = ${DEBS_DIR}"
echo "  ARCHIVE_NAME   = ${ARCHIVE_NAME}"
echo ""

# --- 1단계: Lustre 저장소 추가 ---
echo -e "${YELLOW}[Step 1] Lustre 저장소 추가${NC}"
echo "deb [trusted=yes] https://downloads.whamcloud.com/public/lustre/lustre-2.15.5/ubuntu2204/client /" | sudo tee /etc/apt/sources.list.d/lustre-client.list > /dev/null

# --- 2단계: 패키지 목록 업데이트 ---
echo -e "${YELLOW}[Step 2] 패키지 목록 업데이트${NC}"
sudo apt-get update

# --- 3단계: 필수 도구 설치 ---
echo -e "${YELLOW}[Step 3] 필수 도구 설치 (apt-rdepends, dpkg-dev)${NC}"
sudo apt-get install -y apt-rdepends dpkg-dev

# --- 4단계: 다운로드할 패키지 리스트 정의 ---
BASE_PACKAGES="
linux-headers-${TARGET_KERNEL}
linux-image-${TARGET_KERNEL}
linux-modules-${TARGET_KERNEL}
linux-modules-extra-${TARGET_KERNEL}
build-essential
make
gcc
g++
bison
flex
autoconf
automake
libtool
pkg-config
dkms
python3
python3-distutils
python3-dev
libelf-dev
libssl-dev
perl
pciutils
ethtool
lsof
graphviz
quilt
swig
chrpath
debhelper
dh-autoreconf
dh-python
dpatch
libnl-3-dev
libnl-route-3-dev
libyaml-dev
libreadline-dev
libkeyutils-dev
libmount-dev
zlib1g-dev
binutils-dev
lustre-source
lustre-client-utils
"

echo -e "${YELLOW}[Step 4] 패키지 의존성 다운로드${NC}"
echo "타겟 커널: ${TARGET_KERNEL}"
echo "다운로드 디렉토리: ${DEBS_DIR}"

# 다운로드 디렉토리 생성
mkdir -p "${DEBS_DIR}"

# --- 5단계: 의존성 트리 분석 및 다운로드 ---
echo -e "${YELLOW}[Step 5] 의존성 트리 분석 중...${NC}"
ALL_DEPS=$(apt-rdepends ${BASE_PACKAGES} | grep -v "^ " | grep -v "^PreDepends" | sort -u)

echo -e "${YELLOW}[Step 6] 모든 패키지 다운로드 중...${NC}"
echo "${ALL_DEPS}" | xargs -r sudo apt-get install --reinstall --download-only -y

echo -e "${YELLOW}[Step 7] .deb 파일 복사${NC}"
sudo cp /var/cache/apt/archives/*.deb "./${DEBS_DIR}/"
sudo chown -R $(id -u):$(id -g) "./${DEBS_DIR}"

# --- 6단계: Packages.gz 생성 ---
echo -e "${YELLOW}[Step 8] Packages.gz 인덱스 생성${NC}"
(
    cd "${DEBS_DIR}"
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    echo -e "${GREEN}>> Packages.gz 생성 완료!${NC}"
)

# --- 7단계: 아카이브 생성 (선택사항) ---
if [ "$1" == "--create-archive" ]; then
    echo -e "${YELLOW}[Step 9] 오프라인 배포용 아카이브 생성${NC}"

    # install_offline_advanced.sh를 debs 폴더에 복사
    if [ -f "install_offline_advanced.sh" ]; then
        cp install_offline_advanced.sh "${DEBS_DIR}/"
    fi

    # Makefile 복사 (install-offline 타겟용)
    if [ -f "Makefile" ]; then
        cp Makefile "${DEBS_DIR}/"
    fi

    # .env.example 복사
    if [ -f ".env.example" ]; then
        cp .env.example "${DEBS_DIR}/"
    fi

    tar -czf "../${ARCHIVE_NAME}" "${DEBS_DIR}"
    echo -e "${GREEN}>> 아카이브 생성 완료: ../${ARCHIVE_NAME}${NC}"
fi

echo -e "${GREEN}=== 저장소 빌드 완료! ===${NC}"
echo ""
echo "다음 단계:"
if [ "$1" == "--create-archive" ]; then
    echo "  1. 오프라인 서버로 ../${ARCHIVE_NAME} 파일을 전송하세요."
    echo "  2. 압축 해제 후 'sudo ./install_offline_advanced.sh'를 실행하세요."
else
    echo "  1. 현재 PC에서 테스트: make add-local-repo"
    echo "  2. 오프라인 배포용 아카이브 생성: make repo"
fi
