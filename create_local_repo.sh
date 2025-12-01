#!/bin/bash
set -e

# ==============================================================================
# 로컬 저장소 등록 스크립트
# ==============================================================================
# 현재 디렉토리를 APT 로컬 저장소로 등록합니다.
# ==============================================================================

# 현재 디렉토리의 절대 경로
CURRENT_DIR="$(pwd)"

# 색상 변수
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 로컬 저장소 등록 ===${NC}"

# 1. Packages.gz 파일 확인
if [ ! -f "Packages.gz" ]; then
    echo -e "${YELLOW}경고: Packages.gz 파일이 현재 디렉토리에 없습니다.${NC}"
    echo "저장소 인덱스가 없어도 등록을 진행합니다."
fi

# 2. 로컬 저장소를 등록
# [trusted=yes] 옵션은 GPG 키 서명 없이 설치하게 해줍니다.
echo "로컬 저장소를 등록합니다: $CURRENT_DIR"
echo "deb [trusted=yes] file:$CURRENT_DIR ./" | sudo tee /etc/apt/sources.list.d/local-offline.list

# 3. 패키지 목록 업데이트
echo "패키지 목록을 업데이트합니다..."
sudo apt-get update

echo -e "${GREEN}=== 설정 완료! 이제 apt-get install 명령어를 사용할 수 있습니다. ===${NC}"
