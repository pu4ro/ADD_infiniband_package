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
export REPO_PATH      ?= /repo
export OFED_DIR       ?=

# --- Shell ---
SHELL := /bin/bash

# --- Targets ---

.PHONY: all help download local-repo install-repo add-local-repo repo install-online install-offline clean

all: help

help:
	@echo "Lustre & OFED Offline Installer Kit Makefile"
	@echo ""
	@echo "Current Configuration:"
	@echo "  TARGET_KERNEL = ${TARGET_KERNEL}"
	@echo "  DEBS_DIR      = ${DEBS_DIR}"
	@echo "  ARCHIVE_NAME  = ${ARCHIVE_NAME}"
	@echo "  REPO_PATH     = ${REPO_PATH}"
	@echo "  OFED_DIR      = ${OFED_DIR} (비어있으면 자동 탐지)"
	@echo ""
	@echo "--- 워크플로우 A: 온라인에서 처음부터 빌드 ---"
	@echo "  make download         - 1. 모든 필수 .deb 패키지를 다운로드합니다."
	@echo "  make add-local-repo   - 2. (테스트용) 다운로드한 패키지를 시스템 저장소로 설치하고 현재 PC의 APT 소스에 추가합니다."
	@echo "  make repo             - 2. (배포용) 다운로드한 패키지를 오프라인 배포용 '${ARCHIVE_NAME}' 파일로 압축합니다."
	@echo ""
	@echo "--- 워크플로우 B: 이미 .deb 파일이 있는 경우 ---"
	@echo "  (먼저, '${DEBS_DIR}' 폴더에 직접 .deb 파일들을 위치시키세요)"
	@echo "  make add-local-repo   - 1. (테스트용) 기존 패키지를 시스템 저장소로 설치하고 현재 PC의 APT 소스에 추가합니다."
	@echo "  make repo             - 1. (배포용) 기존 패키지를 오프라인 배포용 '${ARCHIVE_NAME}' 파일로 압축합니다."
	@echo ""
	@echo "--- 기타 명령어 ---"
	@echo "  make install-online   - [온라인 PC] 인터넷을 통해 패키지를 직접 설치합니다."
	@echo "  make install-offline  - [오프라인 서버] 압축 해제 후, 설치 방법을 안내합니다."
	@echo "  make clean            - [모든 PC] 생성된 모든 파일, 시스템 저장소, APT 소스를 삭제합니다."
	@echo ""
	@echo "Configuration Override:"
	@echo "  '.env' 파일을 생성하여 위 변수들의 값을 변경할 수 있습니다. (예: echo 'OFED_DIR := my_ofed_dir' > .env)"

download:
	@echo ">>> 의존성 패키지 다운로드를 시작합니다..."
	@chmod +x download_dependencies.sh
	@./download_dependencies.sh

local-repo:
	@echo ">>> 로컬 APT 저장소 생성을 시작합니다..."
	@chmod +x create_local_repo.sh
	@./create_local_repo.sh

install-repo: local-repo
	@echo ">>> 로컬 저장소를 시스템 경로에 설치합니다..."
	@chmod +x install_local_repo.sh
	@sudo ./install_local_repo.sh

add-local-repo: local-repo
	@echo ">>> 현재 시스템의 APT 소스 리스트에 로컬 저장소를 추가합니다..."
	@chmod +x add_local_repo_to_sources.sh
	@sudo ./add_local_repo_to_sources.sh

repo: local-repo
	@echo ">>> 전체 아카이브 생성을 시작합니다..."
	@chmod +x create_repo_archive.sh
	@./create_repo_archive.sh

install-online:
	@echo ">>> 온라인 설치를 시작합니다..."
	@chmod +x install_online.sh
	@sudo ./install_online.sh

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
	@echo ">>> APT 소스 리스트 및 시스템 저장소를 삭제합니다..."
	@sudo rm -f /etc/apt/sources.list.d/local-builder-repo.list
	@sudo rm -rf ${REPO_PATH}
	@echo ">>> 완료."
