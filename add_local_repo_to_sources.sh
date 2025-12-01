#!/bin/bash
set -e

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
DEBS_DIR=${DEBS_DIR:-"debs"}
SOURCE_LIST_FILE="local-builder-repo.list"

# 스크립트가 루트 권한으로 실행되는지 확인
if [ "$EUID" -ne 0 ]; then
  echo "오류: 이 스크립트는 sudo 또는 루트 권한으로 실행해야 합니다."
  exit 1
fi

echo "=== 현재 PC의 APT 소스 리스트에 로컬 저장소 추가 ==="

# 1. 기존 apt source.list 백업 (최초 1회)
if [ ! -f "/etc/apt/sources.list.backup" ]; then
    echo ">> 기존 /etc/apt/sources.list 파일을 /etc/apt/sources.list.backup 으로 백업합니다..."
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
fi

# 2. 로컬 저장소의 절대 경로 확인
REPO_ABS_PATH="$(pwd)/${DEBS_DIR}"

if [ ! -d "$REPO_ABS_PATH" ]; then
    echo "오류: '${REPO_ABS_PATH}' 폴더를 찾을 수 없습니다."
    echo "'make local-repo'를 먼저 실행했는지 확인하세요."
    exit 1
fi

# 2. APT 소스 리스트 파일 생성
echo "deb [trusted=yes] file:${REPO_ABS_PATH} ./" > "/etc/apt/sources.list.d/${SOURCE_LIST_FILE}"

echo ">> /etc/apt/sources.list.d/${SOURCE_LIST_FILE} 파일 생성 완료."

# 3. 패키지 목록 업데이트
echo ">> apt-get update 실행 중..."
apt-get update

echo "=== 설정 완료! 이제 현재 PC에서 로컬 저장소의 패키지를 'apt-get install'로 설치할 수 있습니다. ==="
