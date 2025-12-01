#!/bin/bash
set -e

# --- 설정 (Makefile 또는 환경변수에서 설정 가능, 없으면 기본값 사용) ---
DEBS_DIR=${DEBS_DIR:-"debs"}
ARCHIVE_NAME=${ARCHIVE_NAME:-"offline_kit.tar.gz"}

# 작업 디렉토리 설정
REPO_DIR="./${DEBS_DIR}"

# OFED 설치 파일 확인 (스크립트 뒷부분에서 압축할 때 필요)
OFED_FILE=$(find . -maxdepth 1 -name "MLNX_OFED_LINUX-*.tgz" | head -n 1)
if [ -z "$OFED_FILE" ]; then
    echo "경고: OFED 설치 파일(.tgz)을 찾을 수 없습니다. 최종 압축 파일에 포함되지 않습니다."
fi

echo "=== 1. 로컬 저장소 생성 도구 설치 (dpkg-dev) ==="
# Packages.gz를 만들기 위해 dpkg-scanpackages 명령어가 필요합니다.
# 이 과정은 인터넷이 연결된 PC에서 한번만 수행하면 됩니다.
sudo apt-get update
sudo apt-get install -y dpkg-dev

echo "=== 2. Packages.gz 인덱스 파일 생성 ==="
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    
    # 패키지 스캔 및 인덱스 생성 (핵심 단계)
    echo "패키지 스캔 중... (시간이 조금 걸릴 수 있습니다)"
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    
    echo ">> Packages.gz 생성 완료!"
    cd ..
else
    echo "오류: '$REPO_DIR' 폴더가 없습니다. 'make download'를 먼저 실행하세요."
    exit 1
fi

echo "=== 3. 최종 압축 ==="
# 모든 관련 파일(debs 폴더, 설치 스크립트 등)을 하나의 tar.gz 파일로 묶습니다.
# 상위 디렉토리에 지정된 이름으로 생성합니다.
echo "현재 디렉토리의 모든 내용을 '../${ARCHIVE_NAME}'으로 압축하는 중..."
tar -czvf "../${ARCHIVE_NAME}" .

echo "성공! 상위 폴더에 '${ARCHIVE_NAME}' 파일이 생성되었습니다."
echo "이 파일을 오프라인 서버로 옮겨서 압축을 해제한 후, 'install_offline_advanced.sh'를 실행하세요."
