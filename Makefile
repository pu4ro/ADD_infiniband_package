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

.PHONY: all help download local-repo repo install-online install-offline clean

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
	@echo "  make download        - [온라인 PC] Lustre/OFED 설치에 필요한 모든 .deb 패키지와 의존성을 '${DEBS_DIR}/' 폴더로 다운로드합니다."
	@echo "  make local-repo      - [온라인 PC] 다운로드된 .deb 파일들을 이용해 '${DEBS_DIR}/' 폴더를 APT 로컬 저장소로 만듭니다. (Packages.gz 인덱싱)"
	@echo "  make repo            - [온라인 PC] 로컬 저장소를 생성하고, 전체 프로젝트를 오프라인 서버로 가져갈 수 있도록 '${ARCHIVE_NAME}' 파일로 압축합니다."
	@echo "  make install-online  - [온라인 PC] 인터넷을 사용해 현재 PC에 Lustre/OFED 관련 패키지를 직접 설치합니다. (오프라인 키트 생성 불필요 시)"
	@echo "  make install-offline - [오프라인 서버] 압축 해제 후, 설치를 진행하는 방법을 안내합니다. (실제 설치는 안내된 명령어를 직접 실행해야 합니다)"
	@echo "  make clean           - [모든 PC] 빌드 과정에서 생성된 '${DEBS_DIR}/' 폴더, '${ARCHIVE_NAME}' 파일 등 모든 결과물을 삭제합니다."
	@echo ""
	@echo "Configuration Override:"
	@echo "  '.env' 파일을 생성하여 위 변수들의 값을 변경할 수 있습니다."
	@echo "  (예: echo 'TARGET_KERNEL := 6.2.0-37-generic' > .env)"

download:
	@echo ">>> 의존성 패키지 다운로드를 시작합니다..."
	@chmod +x download_dependencies.sh
	@./download_dependencies.sh

local-repo: download
	@echo ">>> 로컬 APT 저장소 생성을 시작합니다..."
	@chmod +x create_local_repo.sh
	@./create_local_repo.sh

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
	@echo ">>> 완료."
