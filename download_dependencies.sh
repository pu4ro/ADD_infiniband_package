#!/bin/bash
set -e

# 0. 스크립트 실행 중 오류 발생 시 즉시 중단

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
TARGET_KERNEL=${TARGET_KERNEL:-"5.15.0-25-generic"}
DEBS_DIR=${DEBS_DIR:-"debs"}

# 1. Lustre 저장소 추가
echo "deb [trusted=yes] https://downloads.whamcloud.com/public/lustre/lustre-2.15.5/ubuntu2204/client /" | sudo tee /etc/apt/sources.list.d/lustre-client.list

# 2. 패키지 목록 업데이트
sudo apt-get update

# 3. 재귀적 의존성 다운로드를 위한 도구 설치
sudo apt-get install -y apt-rdepends

# 4. 다운로드할 기본 패키지 리스트
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

echo "=== 모든 의존성 패키지 목록 추출 및 다운로드 시작 ==="
echo "타겟 커널: ${TARGET_KERNEL}"
echo "다운로드 디렉토리: ${DEBS_DIR}"

# 다운로드 디렉토리 생성
mkdir -p "${DEBS_DIR}"

# --- 최적화된 의존성 처리 로직 ---
# 1. 모든 기본 패키지 및 하위 의존성을 한 번에 수집
echo "의존성 트리 분석 중..."
ALL_DEPS=$(apt-rdepends ${BASE_PACKAGES} | grep -v "^ " | grep -v "^PreDepends" | sort -u)

# 2. 수집된 모든 패키지를 한 번의 명령으로 다운로드
echo "모든 패키지 다운로드 중..."
# xargs가 긴 인자 목록을 처리할 수 있도록 분할 실행
echo "${ALL_DEPS}" | xargs -r sudo apt-get install --reinstall --download-only -y

echo "=== 다운로드 완료. .deb 파일들을 정리합니다. ==="

# apt 캐시에 저장된 deb 파일들을 지정된 폴더로 이동
sudo cp /var/cache/apt/archives/*.deb "./${DEBS_DIR}/"

# 권한 정리
sudo chown -R $(id -u):$(id -g) "./${DEBS_DIR}"

echo "=== 작업 완료! 'make repo'를 실행하여 설치 키트를 생성하세요. ==="
