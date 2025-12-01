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

# --- Shell ---
SHELL := /bin/bash

# --- Targets ---

.PHONY: all help download repo install-online install-offline clean

all: help

help:
	@echo "Lustre & OFED Offline Installer Kit Makefile"
	@echo ""
	@echo "Current Configuration:"
	@echo "  TARGET_KERNEL = ${TARGET_KERNEL}"
	@echo "  DEBS_DIR      = ${DEBS_DIR}"
	@echo "  ARCHIVE_NAME  = ${ARCHIVE_NAME}"
	@echo ""
	@echo "Usage:"
	@echo "  make download        - 인터넷 PC에서 모든 의존성 패키지를 '${DEBS_DIR}/' 폴더로 다운로드합니다."
	@echo "  make repo            - 다운로드된 패키지로 로컬 저장소를 만들고 '${ARCHIVE_NAME}' 압축 파일을 생성합니다."
	@echo "  make install-online  - 온라인 PC에 직접 패키지를 설치합니다."
	@echo "  make install-offline - 오프라인 서버에서 설치를 진행하는 방법을 안내합니다."
	@echo "  make clean           - 생성된 모든 파일('${DEBS_DIR}/', '${ARCHIVE_NAME}' 등)을 삭제합니다."
	@echo ""
	@echo "Configuration Override:"
	@echo "  '.env' 파일을 생성하여 위 변수들의 값을 변경할 수 있습니다."
	@echo "  (예: echo 'TARGET_KERNEL := 6.2.0-37-generic' > .env)"

download:
	@echo ">>> 의존성 패키지 다운로드를 시작합니다... (TARGET_KERNEL=${TARGET_KERNEL})"
	@chmod +x download_dependencies.sh
	@./download_dependencies.sh

repo: download
	@echo ">>> 로컬 저장소 생성 및 전체 아카이브 생성을 시작합니다..."
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
	@rm -rf ./debs
	@rm -f ../offline_kit.tar.gz
	@echo ">>> 완료."

