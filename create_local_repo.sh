#!/bin/bash
set -e

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
DEBS_DIR=${DEBS_DIR:-"debs"}

REPO_DIR="./${DEBS_DIR}"

echo "=== 1. 로컬 저장소 생성 도구 설치 (dpkg-dev) ==="
# Packages.gz를 만들기 위해 dpkg-scanpackages 명령어가 필요합니다.
sudo apt-get update
sudo apt-get install -y dpkg-dev

echo "=== 2. Packages.gz 인덱스 파일 생성 ==="
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    
    echo "패키지 스캔 중... (in $(pwd))"
    # 패키지 스캔 및 인덱스 생성 (핵심 단계)
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    
    echo ">> Packages.gz 생성 완료!"
    cd ..
else
    echo "오류: '$REPO_DIR' 폴더가 없습니다. 'make download'를 먼저 실행하세요."
    exit 1
fi

echo "=== 로컬 저장소 생성 완료! ==="
echo "'${DEBS_DIR}' 폴더가 이제 APT 저장소로 사용될 수 있습니다."
