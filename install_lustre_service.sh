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

echo -e "${GREEN}=== Lustre 초기화 서비스 설치 ===${NC}"

# 1. 스크립트 복사
echo -e "${YELLOW}[1/5] 스크립트 복사 중...${NC}"
cp lustre-mount.sh /usr/local/bin/lustre-mount.sh
chmod +x /usr/local/bin/lustre-mount.sh
echo -e "${GREEN}>> /usr/local/bin/lustre-mount.sh 설치 완료${NC}"

# 2. LNet 설정 디렉토리 생성
echo -e "${YELLOW}[2/5] LNet 설정 디렉토리 생성 중...${NC}"
mkdir -p /etc/lustre
echo -e "${GREEN}>> /etc/lustre 디렉토리 생성 완료${NC}"

# 3. LNet 설정 파일 복사
echo -e "${YELLOW}[3/5] LNet 설정 파일 확인 중...${NC}"
if [ ! -f "/etc/lustre/lnetctl.conf" ]; then
    echo -e "${YELLOW}>> LNet 설정 파일이 없습니다. 예제 파일을 복사합니다.${NC}"
    cp lnetctl.conf.example /etc/lustre/lnetctl.conf
    echo -e "${YELLOW}>> /etc/lustre/lnetctl.conf 파일을 편집하여 o2ib 설정을 완료하세요.${NC}"
else
    echo -e "${GREEN}>> 기존 LNet 설정 파일 유지: /etc/lustre/lnetctl.conf${NC}"
fi

# 4. systemd 서비스 파일 복사
echo -e "${YELLOW}[4/5] systemd 서비스 등록 중...${NC}"
cp lustre-mount.service /etc/systemd/system/lustre-mount.service
systemctl daemon-reload
echo -e "${GREEN}>> systemd 서비스 등록 완료${NC}"

# 5. 서비스 활성화 (부팅 시 자동 시작)
echo -e "${YELLOW}[5/5] 서비스 활성화 중...${NC}"
systemctl enable lustre-mount.service
echo -e "${GREEN}>> 서비스 활성화 완료 (부팅 시 자동 시작)${NC}"

echo ""
echo -e "${GREEN}=== 설치 완료! ===${NC}"
echo ""
echo "다음 단계:"
echo "  1. LNet 설정: sudo vi /etc/lustre/lnetctl.conf"
echo "  2. fstab 설정: sudo vi /etc/fstab"
echo "     예: 192.168.1.10@o2ib:/lustre /mnt/lustre lustre defaults,_netdev 0 0"
echo "  3. 서비스 시작: sudo systemctl start lustre-mount"
echo "  4. 상태 확인: sudo systemctl status lustre-mount"
echo ""
echo "수동 실행:"
echo "  시작: sudo /usr/local/bin/lustre-mount.sh start"
echo "  중지: sudo /usr/local/bin/lustre-mount.sh stop"
echo "  상태: sudo /usr/local/bin/lustre-mount.sh status"
