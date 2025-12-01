#!/bin/bash
set -e

# ==============================================================================
# 로컬 저장소 등록 스크립트
# ==============================================================================
# DEBS_DIR 또는 현재 디렉토리를 APT 로컬 저장소로 등록합니다.
# ==============================================================================

# .env 파일이 있으면 DEBS_DIR 로드 (Makefile 형식 처리)
if [ -f ".env" ]; then
    # DEBS_DIR := value 형식을 DEBS_DIR=value로 변환
    eval $(cat .env | grep -v '^#' | grep 'DEBS_DIR' | sed 's/:=/=/g' | sed 's/\s//g')
fi

# DEBS_DIR 환경 변수 처리
DEBS_DIR=${DEBS_DIR:-""}

# DEBS_DIR이 설정되어 있으면 사용, 아니면 현재 디렉토리 사용
if [ -n "$DEBS_DIR" ]; then
    # 절대 경로인지 확인
    if [[ "${DEBS_DIR}" = /* ]]; then
        REPO_DIR="${DEBS_DIR}"
    else
        # 상대 경로면 현재 디렉토리 기준으로 절대 경로 생성
        REPO_DIR="$(pwd)/${DEBS_DIR}"
    fi
else
    # DEBS_DIR이 없으면 현재 디렉토리 사용
    REPO_DIR="$(pwd)"
fi

# 색상 변수
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 로컬 저장소 등록 ===${NC}"
echo "저장소 경로: $REPO_DIR"
echo ""

# 1. 디렉토리 존재 확인
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${RED}오류: 디렉토리 '$REPO_DIR'를 찾을 수 없습니다.${NC}"
    exit 1
fi

# 2. Packages.gz 파일 확인
if [ ! -f "$REPO_DIR/Packages.gz" ]; then
    echo -e "${RED}오류: Packages.gz 파일이 '$REPO_DIR'에 없습니다.${NC}"
    echo "저장소를 먼저 빌드해야 합니다: make build-repo"
    exit 1
fi

# 3. 권한 설정 (_apt 사용자가 접근 가능하도록)
echo "저장소 권한을 설정합니다..."
sudo chmod -R 755 "$REPO_DIR"
sudo chmod 644 "$REPO_DIR"/*.deb 2>/dev/null || true
sudo chmod 644 "$REPO_DIR/Packages.gz"

# 4. 로컬 저장소를 등록
# [trusted=yes] 옵션은 GPG 키 서명 없이 설치하게 해줍니다.
echo "로컬 저장소를 등록합니다: $REPO_DIR"
echo "deb [trusted=yes] file:$REPO_DIR ./" | sudo tee /etc/apt/sources.list.d/local-offline.list

# 5. 패키지 목록 업데이트
echo "패키지 목록을 업데이트합니다..."
sudo apt-get update

echo -e "${GREEN}=== 설정 완료! 이제 apt-get install 명령어를 사용할 수 있습니다. ===${NC}"
