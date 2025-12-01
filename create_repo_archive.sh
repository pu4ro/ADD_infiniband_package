#!/bin/bash
set -e

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
ARCHIVE_NAME=${ARCHIVE_NAME:-"offline_kit.tar.gz"}

echo "=== 최종 압축 시작 ==="

# OFED 설치 파일 확인
OFED_FILE=$(find . -maxdepth 1 -name "MLNX_OFED_LINUX-*.tgz" | head -n 1)
if [ -z "$OFED_FILE" ]; then
    echo "경고: OFED 설치 파일(.tgz)을 찾을 수 없습니다. 최종 압축 파일에 포함되지 않습니다."
fi

# 모든 관련 파일(debs 폴더, 설치 스크립트 등)을 하나의 tar.gz 파일로 묶습니다.
# 상위 디렉토리에 지정된 이름으로 생성합니다.
echo "현재 디렉토리의 모든 내용을 '../${ARCHIVE_NAME}'으로 압축하는 중..."
tar -czvf "../${ARCHIVE_NAME}" .

echo "성공! 상위 폴더에 '${ARCHIVE_NAME}' 파일이 생성되었습니다."
echo "이 파일을 오프라인 서버로 옮겨서 압축을 해제한 후, 설치 스크립트를 실행하세요."

