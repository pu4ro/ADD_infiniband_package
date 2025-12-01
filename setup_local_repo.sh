#!/bin/bash
set -e

# ==============================================================================
# 로컬 저장소 APT 소스 등록 스크립트
# ==============================================================================
# 이 스크립트는 로컬 debs 폴더를 APT 소스에 등록합니다.
# ==============================================================================

# --- 환경 변수 설정 ---
DEBS_DIR=${DEBS_DIR:-"debs"}
SOURCE_LIST_FILE="local-builder-repo.list"

# 색상 변수
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 루트 권한 확인 ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}오류: 이 스크립트는 sudo 또는 루트 권한으로 실행해야 합니다.${NC}"
    exit 1
fi

# --- DEBS_DIR 절대 경로 변환 ---
if [[ "${DEBS_DIR}" = /* ]]; then
    REPO_PATH="${DEBS_DIR}"
else
    # 현재 작업 디렉토리 기준으로 절대 경로 생성
    REPO_PATH="$(pwd)/${DEBS_DIR}"
fi

echo -e "${GREEN}=== 로컬 저장소 APT 소스 등록 ===${NC}"
echo "저장소 경로: ${REPO_PATH}"
echo ""

# --- 1단계: 디렉토리 존재 확인 ---
if [ ! -d "${REPO_PATH}" ]; then
    echo -e "${RED}오류: 저장소 경로 '${REPO_PATH}'를 찾을 수 없습니다.${NC}"
    echo "DEBS_DIR='${DEBS_DIR}' 폴더가 존재하는지 확인하세요."
    exit 1
fi

# --- 2단계: Packages.gz 존재 확인 ---
if [ ! -f "${REPO_PATH}/Packages.gz" ]; then
    echo -e "${RED}오류: '${REPO_PATH}/Packages.gz' 파일을 찾을 수 없습니다.${NC}"
    echo "'make build-repo'를 먼저 실행하여 저장소를 빌드하세요."
    exit 1
fi

# --- 3단계: 기존 sources.list 백업 ---
if [ ! -f "/etc/apt/sources.list.backup" ]; then
    echo -e "${YELLOW}>> 기존 /etc/apt/sources.list 백업 중...${NC}"
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    echo -e "${GREEN}>> 백업 완료: /etc/apt/sources.list.backup${NC}"
fi

# --- 4단계: APT 소스 리스트 파일 생성 ---
echo -e "${YELLOW}>> APT 소스 리스트 생성 중...${NC}"
echo "deb [trusted=yes] file:${REPO_PATH} ./" > "/etc/apt/sources.list.d/${SOURCE_LIST_FILE}"
echo -e "${GREEN}>> /etc/apt/sources.list.d/${SOURCE_LIST_FILE} 생성 완료${NC}"

# --- 5단계: APT 업데이트 ---
echo -e "${YELLOW}>> apt-get update 실행 중...${NC}"
apt-get update

echo ""
echo -e "${GREEN}=== 설정 완료! ===${NC}"
echo "이제 로컬 저장소의 패키지를 'apt-get install'로 설치할 수 있습니다."
echo ""
echo "등록된 저장소:"
echo "  경로: ${REPO_PATH}"
echo "  소스 파일: /etc/apt/sources.list.d/${SOURCE_LIST_FILE}"
