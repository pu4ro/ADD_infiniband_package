# Lustre 및 Mellanox OFED 오프라인 설치 키트 생성 도구

이 프로젝트는 Lustre 클라이언트와 Mellanox OFED 드라이버를 오프라인 환경의 Ubuntu 22.04 서버에 설치하기 위한 완전한 패키지 키트를 생성하는 도구입니다.

## 주요 기능
- 필요한 모든 패키지의 의존성을 재귀적으로 다운로드합니다.
- 오프라인 서버에서 `apt` 명령어를 사용할 수 있도록 로컬 Debian 저장소를 생성합니다.
- 커널 버전 체크, OFED 드라이버 설치, Lustre 클라이언트 빌드를 자동화하는 통합 설치 스크립트를 제공합니다.
- `Makefile`을 통해 전체 과정을 단순화합니다.

## 사전 준비사항
1. **온라인 PC**: Ubuntu 22.04가 설치되어 있고, 인터넷 연결이 가능한 PC.
2. **오프라인 서버**: 최종적으로 패키지를 설치할 Ubuntu 22.04 서버.
3. **OFED 드라이버**: Mellanox (NVIDIA) 사이트에서 `MLNX_OFED_LINUX-*.tgz` 형태의 드라이버를 다운로드하여 이 프로젝트 폴더의 최상위 경로에 위치시킵니다.

---
## 설정 (Configuration)

기본 설정은 `Makefile`에 정의되어 있습니다. 만약 설정을 변경하고 싶다면, `Makefile`을 직접 수정하는 대신 `.env` 파일을 생성하여 설정을 덮어쓸 수 있습니다.

1. `.env.example` 파일을 `.env` 파일로 복사합니다.
   ```bash
   cp .env.example .env
   ```
2. `.env` 파일을 열고 원하는 값으로 수정합니다.
   ```
   # .env 파일 내용 예시
   TARGET_KERNEL  := 6.2.0-37-generic
   DEBS_DIR       := my_debs
   ARCHIVE_NAME   := my_lustre_kit.tar.gz
   REPO_PATH      := /opt/my-local-repo
   # OFED 설치 디렉토리를 직접 지정할 수 있습니다. (비워두면 자동 탐지)
   OFED_DIR       :=
   ```
3. `make` 명령어를 실행하면 `.env` 파일에 설정된 값을 기준으로 작업을 수행합니다. `make help` 명령어로 현재 적용된 설정을 확인할 수 있습니다.

---

## 사용 방법 (`Makefile` 사용)

두 가지 주요 작업 흐름이 있습니다.

### 워크플로우 A: 처음부터 온라인 PC에서 모든 것을 생성하는 경우

인터넷이 연결된 PC에서 `.deb` 파일 다운로드부터 모든 것을 시작합니다.

1. **의존성 패키지 다운로드**
   ```bash
   make download
   ```
2. **이후 작업 진행**
   - 다운로드가 완료된 후, 필요한 다음 단계를 진행합니다.
   - 예 1: 오프라인 배포용 `.tar.gz` 아카이브 생성
     ```bash
     make repo
     ```
   - 예 2: 현재 PC에서 바로 저장소를 테스트하기 위해 시스템에 저장소 설치 및 `apt` 소스 추가
     ```bash
     make add-local-repo
     ```

### 워크플로우 B: 이미 `.deb` 파일들을 가지고 있는 경우

다른 경로에서 `.deb` 파일들을 이미 확보한 경우, `download` 단계를 건너뛸 수 있습니다.

1. **`.deb` 파일 준비**
   - `.env` 파일에 `DEBS_DIR` 변수를 설정하고 (기본값: `debs`), 해당 폴더에 가지고 있는 모든 `.deb` 파일들을 위치시킵니다.

2. **저장소 구성 및 설치 진행**
   - `download`를 제외한 원하는 다음 단계를 바로 실행합니다.
   - 예: 즉시 현재 PC의 `apt` 소스로 사용하기
     ```bash
     make add-local-repo
     ```

### 오프라인 서버에서 설치

두 워크플로우 모두 `make repo`를 통해 생성된 아카이브 파일을 오프라인 서버로 가져가서 설치를 진행합니다.

1. **압축 해제**
   ```bash
   tar -xzvf <ARCHIVE_NAME>
   ```
2. **설치 스크립트 실행**
   - 압축 해제 후 생성된 폴더로 이동하여, `make install-offline` 명령으로 안내를 확인하고, 안내된 `sudo` 명령어를 실행합니다.
   ```bash
   cd <압축 해제된 폴더명>
   make install-offline
   ```

### 주요 명령어 상세 설명

#### `make add-local-repo`의 동작 원리
이 명령어는 `Makefile`의 의존성 규칙에 따라 다음 작업을 순차적으로 실행합니다. (`download`는 더 이상 자동 의존성이 아닙니다.)

1.  **`make local-repo` 실행**: `${DEBS_DIR}` 폴더의 `.deb` 파일들로 `Packages.gz` 인덱스를 생성하여 폴더를 로컬 저장소로 만듭니다.
2.  **`make install-repo` 실행**: 생성된 로컬 저장소를 시스템 경로(`${REPO_PATH}`)로 복사하고 `_apt` 사용자 권한을 설정합니다.
3.  **`make add-local-repo` 실행**: 최종 설치된 시스템 저장소의 경로를 현재 PC의 `apt` 소스 리스트에 추가하고 `apt-get update`를 실행합니다.

---

## Makefile Targets 상세 설명

- `make download`: [워크플로우 A] 모든 의존성 `.deb` 패키지를 다운로드합니다.
- `make local-repo`: [워크플로우 B] 준비된 `.deb` 폴더를 로컬 APT 저장소로 만듭니다. (다운로드 단계 없음)
- `make install-repo`: 로컬 저장소를 시스템 경로(`${REPO_PATH}`)에 설치하고 권한을 설정합니다.
- `make add-local-repo`: 시스템에 설치된 저장소를 현재 PC의 `apt` 소스에 추가합니다. (`local-repo` 및 `install-repo` 포함)
- `make repo`: `local-repo` 완료 후, 오프라인 배포를 위해 전체 폴더를 압축합니다.
- `make clean`: 생성된 모든 빌드 결과물, 시스템 저장소, `apt` 소스 리스트를 삭제합니다.
- `make install-online`: 온라인 환경에서 패키지를 직접 설치합니다.
- `make install-offline`: 오프라인 환경에서 설치하는 방법을 안내합니다.
- `make help`: 사용 가능한 모든 타겟 목록과 현재 설정을 보여줍니다.
