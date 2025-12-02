# ==============================================================================
# Lustre Client & Mellanox OFED Offline Installer Kit - Makefile
# ==============================================================================
# 이 Makefile은 Ubuntu 22.04 서버용 Lustre 클라이언트와 OFED 드라이버의
# 오프라인 설치 키트를 빌드하고 배포하는 전체 워크플로우를 제공합니다.
#
# 주요 사용 시나리오:
# 1. 온라인 PC에서 패키지 다운로드 및 아카이브 생성
# 2. 오프라인 서버로 아카이브 전송 및 설치
# ==============================================================================

# --- Configuration ---
# .env 파일이 있으면 해당 설정을 불러와 기본값을 덮어씁니다.
-include .env

# 스크립트에서 사용할 변수들을 여기서 지정합니다.
# .env 파일에 아래 변수들을 정의하여 이 값을 오버라이드할 수 있습니다.
export TARGET_KERNEL  ?= 5.15.0-25-generic
export DEBS_DIR       ?= debs
export ARCHIVE_NAME   ?= offline_kit.tar.gz
export OFED_DIR       ?=
export REPO_PATH      ?= /opt/local-repo

# --- Shell ---
SHELL := /bin/bash

# --- Color Output ---
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
NC     := \033[0m # No Color

# --- Targets ---

.PHONY: all help build-repo add-local-repo create-local-repo repo install-offline install-lustre-service clean download info check-env clean-cache clean-all

all: help

help:
	@echo ""
	@echo "$(GREEN)================================================================$(NC)"
	@echo "$(GREEN)  Lustre Client & OFED Offline Installer Kit - Makefile$(NC)"
	@echo "$(GREEN)================================================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Current Configuration:$(NC)"
	@echo "  TARGET_KERNEL = $(BLUE)${TARGET_KERNEL}$(NC)"
	@echo "  DEBS_DIR      = $(BLUE)${DEBS_DIR}$(NC)"
	@echo "  ARCHIVE_NAME  = $(BLUE)${ARCHIVE_NAME}$(NC)"
	@echo "  REPO_PATH     = $(BLUE)${REPO_PATH}$(NC)"
	@echo "  OFED_DIR      = $(BLUE)${OFED_DIR}$(NC) $(YELLOW)(비어있으면 자동 탐지)$(NC)"
	@echo ""
	@echo "$(YELLOW)=== 빠른 시작 가이드 ===$(NC)"
	@echo "$(GREEN)[온라인 PC]$(NC)"
	@echo "  1. make download      - 필요한 모든 패키지 다운로드"
	@echo "  2. make repo          - 오프라인 배포용 아카이브 생성"
	@echo "  3. 생성된 offline_kit.tar.gz를 오프라인 서버로 전송"
	@echo ""
	@echo "$(GREEN)[오프라인 서버]$(NC)"
	@echo "  1. tar -xzvf offline_kit.tar.gz"
	@echo "  2. cd offline_kit"
	@echo "  3. sudo ./install_offline_advanced.sh"
	@echo ""
	@echo "$(YELLOW)=== 온라인 PC 워크플로우 (상세) ===$(NC)"
	@echo "  $(GREEN)make download$(NC)"
	@echo "    - Lustre 클라이언트 패키지 다운로드"
	@echo "    - 커널 패키지 (linux-image, linux-headers, linux-modules)"
	@echo "    - 빌드 도구 및 의존성 다운로드"
	@echo "    - 모든 의존성을 재귀적으로 다운로드"
	@echo ""
	@echo "  $(GREEN)make build-repo$(NC)"
	@echo "    - 다운로드된 패키지로 로컬 APT 저장소 생성"
	@echo "    - Packages.gz 인덱스 파일 생성"
	@echo ""
	@echo "  $(GREEN)make repo$(NC)"
	@echo "    - 오프라인 배포용 tar.gz 아카이브 생성"
	@echo "    - 설치 스크립트 포함"
	@echo "    - OFED 드라이버는 별도로 /root에 배치 필요"
	@echo ""
	@echo "  $(GREEN)make add-local-repo$(NC)"
	@echo "    - [테스트용] 현재 PC에 로컬 저장소 등록"
	@echo "    - /etc/apt/sources.list.d/에 추가"
	@echo ""
	@echo "$(YELLOW)=== 오프라인 서버 워크플로우 ===$(NC)"
	@echo "  $(GREEN)make install-offline$(NC)"
	@echo "    - 오프라인 설치 안내 메시지 출력"
	@echo "    - 실제 설치: sudo ./install_offline_advanced.sh"
	@echo ""
	@echo "  $(BLUE)install_offline_advanced.sh 동작 순서:$(NC)"
	@echo "    Step 1: 로컬 저장소 등록 (debs/ 디렉토리)"
	@echo "    Step 2: 커널 버전 확인 및 설치"
	@echo "    Step 3: OFED 드라이버 설치 (/root에서 자동 탐지)"
	@echo "    Step 4: 빌드 도구 및 의존성 설치"
	@echo "    Step 5: Lustre 클라이언트 빌드 및 설치"
	@echo "    Step 6: 설치 검증"
	@echo ""
	@echo "  $(GREEN)make install-lustre-service$(NC)"
	@echo "    - Lustre 자동 마운트 systemd 서비스 설치"
	@echo "    - LNet 설정 및 fstab 자동 구성"
	@echo ""
	@echo "$(YELLOW)=== 유틸리티 명령어 ===$(NC)"
	@echo "  $(GREEN)make info$(NC)          - 시스템 정보 및 설치 상태 확인"
	@echo "  $(GREEN)make check-env$(NC)     - 환경 설정 검증"
	@echo "  $(GREEN)make clean$(NC)         - 생성된 파일 및 APT 소스 삭제"
	@echo "  $(GREEN)make clean-cache$(NC)   - APT 캐시만 삭제"
	@echo "  $(GREEN)make clean-all$(NC)     - 모든 파일, APT 소스, 캐시 삭제"
	@echo "  $(GREEN)make help$(NC)          - 이 도움말 표시"
	@echo ""
	@echo "$(YELLOW)=== 설정 변경 ===$(NC)"
	@echo "  '.env' 파일을 생성하여 위 변수들의 값을 변경할 수 있습니다."
	@echo "  $(BLUE)예시:$(NC)"
	@echo "    cp .env.example .env"
	@echo "    vi .env"
	@echo "    $(YELLOW)# TARGET_KERNEL=5.15.0-100-generic 으로 수정$(NC)"
	@echo ""
	@echo "$(YELLOW)=== OFED 드라이버 준비 ===$(NC)"
	@echo "  오프라인 서버의 /root 디렉토리에 다음 파일 배치:"
	@echo "    - MLNX_OFED_LINUX-*.tgz"
	@echo "  또는 .env에서 OFED_DIR 지정"
	@echo ""
	@echo "$(GREEN)================================================================$(NC)"
	@echo ""

download:
	@echo "$(YELLOW)>>> [온라인 PC] 패키지 다운로드 시작...$(NC)"
	@echo "$(BLUE)Target Kernel: ${TARGET_KERNEL}$(NC)"
	@chmod +x download_dependencies.sh
	@./download_dependencies.sh
	@echo "$(GREEN)>>> 다운로드 완료. ${DEBS_DIR}/ 디렉토리를 확인하세요.$(NC)"

build-repo:
	@echo "$(YELLOW)>>> [온라인 PC] 로컬 APT 저장소 빌드 시작...$(NC)"
	@chmod +x build_repo.sh
	@./build_repo.sh
	@echo "$(GREEN)>>> 로컬 저장소 빌드 완료.$(NC)"

add-local-repo:
	@echo "$(YELLOW)>>> [테스트용] 로컬 저장소를 APT 소스에 추가합니다...$(NC)"
	@chmod +x setup_local_repo.sh
	@sudo ./setup_local_repo.sh
	@echo "$(GREEN)>>> APT 소스 등록 완료. 'apt-cache policy' 명령어로 확인하세요.$(NC)"

create-local-repo:
	@echo "$(YELLOW)>>> 현재 디렉토리를 APT 소스에 직접 등록합니다...$(NC)"
	@chmod +x create_local_repo.sh
	@./create_local_repo.sh
	@echo "$(GREEN)>>> 로컬 저장소 등록 완료.$(NC)"

repo:
	@echo "$(YELLOW)>>> [온라인 PC] 오프라인 배포용 아카이브 생성 시작...$(NC)"
	@chmod +x build_repo.sh
	@./build_repo.sh --create-archive
	@echo "$(GREEN)>>> 아카이브 생성 완료: ${ARCHIVE_NAME}$(NC)"
	@echo "$(BLUE)>>> 이 파일을 오프라인 서버로 전송하세요.$(NC)"

install-offline:
	@echo ""
	@echo "$(GREEN)================================================================$(NC)"
	@echo "$(GREEN)           오프라인 설치 안내$(NC)"
	@echo "$(GREEN)================================================================$(NC)"
	@echo ""
	@echo "$(YELLOW)[설치 전 준비사항]$(NC)"
	@echo "  1. OFED 드라이버를 /root 디렉토리에 배치:"
	@echo "     $(BLUE)cp MLNX_OFED_LINUX-*.tgz /root/$(NC)"
	@echo ""
	@echo "$(YELLOW)[설치 명령어]$(NC)"
	@echo "  현재 디렉토리에서 아래 명령어를 실행:"
	@echo "  $(GREEN)sudo ./install_offline_advanced.sh$(NC)"
	@echo ""
	@echo "$(YELLOW)[설치 과정]$(NC)"
	@echo "  Step 1: 로컬 저장소 등록"
	@echo "  Step 2: 커널 확인 및 설치 $(RED)(재부팅 필요할 수 있음)$(NC)"
	@echo "  Step 3: OFED 드라이버 설치"
	@echo "  Step 4: 의존성 패키지 설치"
	@echo "  Step 5: Lustre 클라이언트 빌드"
	@echo "  Step 6: 설치 검증"
	@echo ""
	@echo "$(RED)[중요]$(NC) 커널 설치 후 재부팅이 필요하면:"
	@echo "  1. 재부팅 수행"
	@echo "  2. 다시 이 디렉토리로 이동"
	@echo "  3. $(GREEN)sudo ./install_offline_advanced.sh$(NC) 재실행"
	@echo ""
	@echo "$(GREEN)================================================================$(NC)"
	@echo ""

install-lustre-service:
	@echo "$(YELLOW)>>> Lustre 자동 마운트 서비스 설치 중...$(NC)"
	@chmod +x install_lustre_service.sh
	@sudo ./install_lustre_service.sh
	@echo "$(GREEN)>>> Lustre 서비스 설치 완료.$(NC)"
	@echo "$(BLUE)>>> systemctl status lustre-client.service 로 확인하세요.$(NC)"

info:
	@echo ""
	@echo "$(GREEN)================================================================$(NC)"
	@echo "$(GREEN)           시스템 정보 및 설치 상태$(NC)"
	@echo "$(GREEN)================================================================$(NC)"
	@echo ""
	@echo "$(YELLOW)[현재 시스템]$(NC)"
	@echo -n "  OS: "
	@cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo "Unknown"
	@echo "  현재 커널: $$(uname -r)"
	@echo "  타겟 커널: $(BLUE)${TARGET_KERNEL}$(NC)"
	@echo ""
	@echo "$(YELLOW)[Lustre 상태]$(NC)"
	@if lsmod | grep -q lustre; then \
		echo "  Lustre 모듈: $(GREEN)로드됨$(NC)"; \
		lsmod | grep lustre | head -3; \
	else \
		echo "  Lustre 모듈: $(RED)로드 안됨$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)[OFED 상태]$(NC)"
	@if systemctl is-active --quiet openibd 2>/dev/null; then \
		echo "  OFED 서비스: $(GREEN)실행 중$(NC)"; \
	else \
		echo "  OFED 서비스: $(RED)실행 안됨$(NC)"; \
	fi
	@if command -v ibstat >/dev/null 2>&1; then \
		echo "  InfiniBand: $(GREEN)설치됨$(NC)"; \
	else \
		echo "  InfiniBand: $(RED)설치 안됨$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)[패키지 상태]$(NC)"
	@if [ -d "${DEBS_DIR}" ]; then \
		echo "  패키지 디렉토리: $(GREEN)존재함$(NC) (${DEBS_DIR}/)"; \
		echo "  패키지 개수: $$(ls -1 ${DEBS_DIR}/*.deb 2>/dev/null | wc -l) 개"; \
	else \
		echo "  패키지 디렉토리: $(RED)없음$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)================================================================$(NC)"
	@echo ""

check-env:
	@echo ""
	@echo "$(YELLOW)>>> 환경 설정 검증 중...$(NC)"
	@echo ""
	@if [ -f .env ]; then \
		echo "$(GREEN)✓$(NC) .env 파일 존재"; \
		cat .env; \
	else \
		echo "$(YELLOW)⚠$(NC) .env 파일 없음 (기본값 사용)"; \
		echo "  .env.example을 복사하여 .env 생성 권장"; \
	fi
	@echo ""
	@if [ -f .env.example ]; then \
		echo "$(GREEN)✓$(NC) .env.example 파일 존재"; \
	else \
		echo "$(RED)✗$(NC) .env.example 파일 없음"; \
	fi
	@echo ""
	@echo "$(YELLOW)현재 설정값:$(NC)"
	@echo "  TARGET_KERNEL  = ${TARGET_KERNEL}"
	@echo "  DEBS_DIR       = ${DEBS_DIR}"
	@echo "  ARCHIVE_NAME   = ${ARCHIVE_NAME}"
	@echo "  REPO_PATH      = ${REPO_PATH}"
	@echo "  OFED_DIR       = ${OFED_DIR}"
	@echo ""
	@if command -v dpkg-scanpackages >/dev/null 2>&1; then \
		echo "$(GREEN)✓$(NC) dpkg-scanpackages 설치됨"; \
	else \
		echo "$(RED)✗$(NC) dpkg-scanpackages 미설치 (dpkg-dev 패키지 필요)"; \
	fi
	@echo ""

clean:
	@echo "$(RED)>>> 생성된 파일들을 삭제합니다...$(NC)"
	@echo "  - ${DEBS_DIR}/ 디렉토리 삭제"
	@rm -rf ./${DEBS_DIR}
	@echo "  - ${ARCHIVE_NAME} 아카이브 삭제"
	@rm -f ../${ARCHIVE_NAME}
	@rm -f ./${ARCHIVE_NAME}
	@echo "  - Packages.gz 인덱스 삭제"
	@rm -f ./Packages.gz
	@echo "$(YELLOW)>>> APT 소스 리스트를 삭제합니다...$(NC)"
	@sudo rm -f /etc/apt/sources.list.d/local-builder-repo.list
	@sudo rm -f /etc/apt/sources.list.d/local-repo.list
	@echo "$(YELLOW)>>> 시스템 로컬 저장소를 삭제합니다...$(NC)"
	@sudo rm -rf ${REPO_PATH}
	@echo "$(GREEN)>>> 정리 완료.$(NC)"

clean-cache:
	@echo "$(YELLOW)>>> APT 캐시를 삭제합니다...$(NC)"
	@echo "  - apt-get clean (다운로드된 패키지 파일 삭제)"
	@sudo apt-get clean
	@echo "  - apt-get autoclean (오래된 패키지 파일 삭제)"
	@sudo apt-get autoclean
	@echo "  - /var/cache/apt/archives/ 용량:"
	@du -sh /var/cache/apt/archives/ 2>/dev/null || echo "    (비어있음)"
	@echo "$(GREEN)>>> APT 캐시 삭제 완료.$(NC)"

clean-all: clean clean-cache
	@echo "$(GREEN)>>> 전체 정리 완료 (파일 + APT 소스 + 캐시).$(NC)"
