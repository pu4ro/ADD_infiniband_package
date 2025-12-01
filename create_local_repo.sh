#!/bin/bash
set -e

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
DEBS_DIR=${DEBS_DIR:-"debs"}

# DEBS_DIR이 절대 경로인지 상대 경로인지 판단
if [[ "${DEBS_DIR}" = /* ]]; then
    # 절대 경로인 경우 그대로 사용
    REPO_DIR="${DEBS_DIR}"
else
    # 상대 경로인 경우 현재 작업 디렉토리 기준으로 절대 경로 생성
    REPO_DIR="$(pwd)/${DEBS_DIR}"
fi

echo "=== 로컬 저장소 확인 ==="
if [ ! -d "$REPO_DIR" ]; then
    echo "오류: '$REPO_DIR' 폴더가 없습니다."
    exit 1
fi

if [ ! -f "$REPO_DIR/Packages.gz" ]; then
    echo "경고: '$REPO_DIR/Packages.gz' 파일이 없습니다."
    echo "해당 폴더에 Packages.gz 파일이 이미 생성되어 있어야 합니다."
    exit 1
fi

echo "=== 로컬 저장소 확인 완료! ==="
echo "'${DEBS_DIR}' 폴더가 APT 저장소로 사용될 수 있습니다."
