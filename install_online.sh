#!/bin/bash
set -e

# 1. Lustre 저장소 추가
echo "deb [trusted=yes] https://downloads.whamcloud.com/public/lustre/lustre-2.15.5/ubuntu2204/client /" | sudo tee /etc/apt/sources.list.d/lustre-client.list

# 2. 패키지 목록 업데이트
sudo apt-get update

# 3. 타겟 커널 버전 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용)
TARGET_KERNEL=${TARGET_KERNEL:-"5.15.0-25-generic"}

# 4. 설치할 패키지 리스트
PACKAGES="
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

echo "=== 패키지 설치 시작 ==="

sudo apt-get install -y $PACKAGES

echo "=== 온라인 설치 완료! ==="
