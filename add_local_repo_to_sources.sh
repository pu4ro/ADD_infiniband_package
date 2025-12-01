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

# DEBS_DIR이 절대 경로인지 상대 경로인지 판단하여 절대 경로로 변환
if [[ "${DEBS_DIR}" = /* ]]; then
    # 절대 경로인 경우 그대로 사용
    REPO_PATH="${DEBS_DIR}"
else
    # 상대 경로인 경우 현재 디렉토리 기준으로 절대 경로 생성
    REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${DEBS_DIR}"
fi

echo "=== 현재 PC의 APT 소스 리스트에 로컬 저장소(${REPO_PATH}) 추가 ==="

# 1. 기존 apt source.list 백업 (최초 1회)
if [ ! -f "/etc/apt/sources.list.backup" ]; then
    echo ">> 기존 /etc/apt/sources.list 파일을 /etc/apt/sources.list.backup 으로 백업합니다..."
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
fi

# 2. 로컬 저장소 경로 확인
if [ ! -d "${REPO_PATH}" ]; then
    echo "오류: 로컬 저장소 경로 '${REPO_PATH}'를 찾을 수 없습니다."
    echo "'${DEBS_DIR}' 폴더가 존재하는지 확인하세요."
    exit 1
fi

# 3. Packages.gz 파일 확인
if [ ! -f "${REPO_PATH}/Packages.gz" ]; then
    echo "오류: '${REPO_PATH}/Packages.gz' 파일을 찾을 수 없습니다."
    echo "'make local-repo'를 먼저 실행하여 저장소 인덱스를 생성하세요."
    exit 1
fi

# 4. APT 소스 리스트 파일 생성
echo "deb [trusted=yes] file:${REPO_PATH} ./" > "/etc/apt/sources.list.d/${SOURCE_LIST_FILE}"

echo ">> /etc/apt/sources.list.d/${SOURCE_LIST_FILE} 파일 생성 완료."

# 5. 패키지 목록 업데이트
echo ">> apt-get update 실행 중..."
apt-get update

echo "=== 설정 완료! 이제 현재 PC에서 '${REPO_PATH}'의 패키지를 'apt-get install'로 설치할 수 있습니다. ==="
