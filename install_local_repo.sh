#!/bin/bash
set -e

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
DEBS_DIR=${DEBS_DIR:-"debs"}
REPO_PATH=${REPO_PATH:-"/repo"}

# 스크립트가 루트 권한으로 실행되는지 확인
if [ "$EUID" -ne 0 ]; then
  echo "오류: 이 스크립트는 sudo 또는 루트 권한으로 실행해야 합니다."
  exit 1
fi

echo "=== 로컬 저장소를 시스템 경로(${REPO_PATH})에 설치합니다 ==="

# 1. 소스 디렉토리 확인
if [ ! -d "${DEBS_DIR}" ]; then
    echo "오류: 소스 디렉토리 '${DEBS_DIR}'를 찾을 수 없습니다."
    echo "'make local-repo'를 먼저 실행했는지 확인하세요."
    exit 1
fi

# 2. 타겟 디렉토리 생성
echo ">> 타겟 디렉토리 생성: ${REPO_PATH}"
mkdir -p "${REPO_PATH}"

# 3. 파일 복사
echo ">> '${DEBS_DIR}'의 모든 파일을 '${REPO_PATH}'(으)로 복사합니다..."
# rsync를 사용하여 효율적으로 복사하고, 마지막 '/'를 붙여 내용물만 복사하도록 함
rsync -av --delete "${DEBS_DIR}/" "${REPO_PATH}/"

# 4. 권한 설정
echo ">> '${REPO_PATH}'의 소유자를 '_apt' 사용자로 변경합니다..."
# _apt 사용자가 존재하지 않을 경우를 대비하여 에러를 무시하지 않음
# chown -R _apt:_apt "${REPO_PATH}" || echo "경고: '_apt' 사용자를 찾을 수 없어 권한 변경을 건너뜁니다."
chown -R _apt:_apt "${REPO_PATH}"

echo "=== 시스템 저장소 설치 완료! ==="
echo "이제 '${REPO_PATH}' 경로가 APT 저장소로 사용될 수 있습니다."
