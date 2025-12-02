#!/bin/bash
# ==============================================================================
# Lustre 마운트 서비스 설치 스크립트
# ==============================================================================

set -e

# 색상 변수
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}오류: 이 스크립트는 sudo 또는 루트 권한으로 실행해야 합니다.${NC}"
    exit 1
fi

echo -e "${GREEN}=== Lustre 마운트 서비스 설치 ===${NC}"

# 1. 스크립트 복사
echo -e "${YELLOW}[1/4] 스크립트 복사 중...${NC}"
cp lustre-mount.sh /usr/local/bin/lustre-mount.sh
chmod +x /usr/local/bin/lustre-mount.sh
echo -e "${GREEN}>> /usr/local/bin/lustre-mount.sh 설치 완료${NC}"

# 2. 설정 파일 복사
echo -e "${YELLOW}[2/4] 설정 파일 확인 중...${NC}"
if [ ! -f "/etc/lustre-mount.conf" ]; then
    echo -e "${YELLOW}>> 설정 파일이 없습니다. 예제 파일을 복사합니다.${NC}"
    cp lustre-mount.conf.example /etc/lustre-mount.conf
    echo -e "${YELLOW}>> /etc/lustre-mount.conf 파일을 편집하여 설정을 완료하세요.${NC}"
else
    echo -e "${GREEN}>> 기존 설정 파일 유지: /etc/lustre-mount.conf${NC}"
fi

# 3. systemd 서비스 파일 복사
echo -e "${YELLOW}[3/4] systemd 서비스 등록 중...${NC}"
cp lustre-mount.service /etc/systemd/system/lustre-mount.service
systemctl daemon-reload
echo -e "${GREEN}>> systemd 서비스 등록 완료${NC}"

# 4. 서비스 활성화 (부팅 시 자동 시작)
echo -e "${YELLOW}[4/4] 서비스 활성화 중...${NC}"
systemctl enable lustre-mount.service
echo -e "${GREEN}>> 서비스 활성화 완료 (부팅 시 자동 시작)${NC}"

echo ""
echo -e "${GREEN}=== 설치 완료! ===${NC}"
echo ""
echo "다음 단계:"
echo "  1. 설정 파일 편집: sudo vi /etc/lustre-mount.conf"
echo "  2. 서비스 시작: sudo systemctl start lustre-mount"
echo "  3. 상태 확인: sudo systemctl status lustre-mount"
echo ""
echo "수동 실행:"
echo "  시작: sudo /usr/local/bin/lustre-mount.sh start"
echo "  중지: sudo /usr/local/bin/lustre-mount.sh stop"
echo "  상태: sudo /usr/local/bin/lustre-mount.sh status"
