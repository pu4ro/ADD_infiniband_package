# ==============================================================================
# Lustre & OFED Offline Installer Kit Makefile
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

# --- Shell ---
SHELL := /bin/bash

# --- Targets ---

.PHONY: all help build-repo add-local-repo create-local-repo repo install-offline clean

all: help

help:
	@echo "Lustre & OFED Offline Installer Kit Makefile"
	@echo ""
	@echo "Current Configuration:"
	@echo "  TARGET_KERNEL = ${TARGET_KERNEL}"
	@echo "  DEBS_DIR      = ${DEBS_DIR}"
	@echo "  ARCHIVE_NAME  = ${ARCHIVE_NAME}"
	@echo "  OFED_DIR      = ${OFED_DIR} (비어있으면 자동 탐지)"
	@echo ""
	@echo "=== 온라인 PC 워크플로우 ==="
	@echo "  make build-repo       - [온라인] 패키지 다운로드 및 Packages.gz 생성"
	@echo "  make add-local-repo   - [온라인] 로컬 저장소를 현재 PC의 APT 소스에 추가"
	@echo "  make create-local-repo - [모든 환경] 현재 디렉토리를 APT 소스에 직접 등록"
	@echo "  make repo             - [온라인] 오프라인 배포용 아카이브 생성"
	@echo ""
	@echo "=== 오프라인 서버 워크플로우 ==="
	@echo "  make install-offline  - [오프라인] 압축 해제 후 설치 방법 안내"
	@echo ""
	@echo "=== 기타 ==="
	@echo "  make clean            - 생성된 모든 파일 및 APT 소스 삭제"
	@echo "  make help             - 이 도움말 표시"
	@echo ""
	@echo "Configuration Override:"
	@echo "  '.env' 파일을 생성하여 위 변수들의 값을 변경할 수 있습니다."
	@echo "  예: cp .env.example .env && vi .env"

build-repo:
	@echo ">>> 온라인 저장소 빌드를 시작합니다..."
	@chmod +x build_repo.sh
	@./build_repo.sh

add-local-repo:
	@echo ">>> 로컬 저장소를 APT 소스에 추가합니다..."
	@chmod +x setup_local_repo.sh
	@sudo ./setup_local_repo.sh

create-local-repo:
	@echo ">>> 현재 디렉토리를 APT 소스에 등록합니다..."
	@chmod +x create_local_repo.sh
	@./create_local_repo.sh

repo:
	@echo ">>> 오프라인 배포용 아카이브를 생성합니다..."
	@chmod +x build_repo.sh
	@./build_repo.sh --create-archive

install-offline:
	@echo "========================= 오프라인 설치 안내 ========================="
	@echo "1. 현재 디렉토리에서 아래 명령어를 실행하여 설치를 시작하세요."
	@echo "   (커널 설치 및 재부팅이 필요할 수 있습니다)"
	@echo ""
	@echo "   sudo ./install_offline_advanced.sh"
	@echo ""
	@echo "2. 재부팅 후에는 다시 이 디렉토리로 와서 위 명령어를 반복 실행하세요."
	@echo "========================================================================"

clean:
	@echo ">>> 생성된 파일들을 삭제합니다..."
	@rm -rf ./${DEBS_DIR}
	@rm -f ../${ARCHIVE_NAME}
	@echo ">>> APT 소스 리스트를 삭제합니다..."
	@sudo rm -f /etc/apt/sources.list.d/local-builder-repo.list
	@echo ">>> 완료."
