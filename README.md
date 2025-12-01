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
   ```
3. `make` 명령어를 실행하면 `.env` 파일에 설정된 값을 기준으로 작업을 수행합니다. `make help` 명령어로 현재 적용된 설정을 확인할 수 있습니다.

---

## 사용 방법 (`Makefile` 사용)

`Makefile`을 사용하면 전체 과정을 간단하게 처리할 수 있습니다.

### 1단계: 온라인 PC에서 설치 키트 생성

1. **의존성 패키지 다운로드**
   - `debs` 폴더에 모든 패키지를 다운로드합니다.
   ```bash
   make download
   ```

2. **오프라인 저장소 아카이브 생성**
   - 다운로드된 패키지로 로컬 저장소를 구성하고, 프로젝트 전체를 `offline_kit.tar.gz` 파일로 압축합니다.
   - 이 파일은 프로젝트의 상위 폴더(`../`)에 생성됩니다.
   ```bash
   make repo
   ```

3. **파일 전송**
   - 생성된 `offline_kit.tar.gz` 파일을 USB 등의 매체를 이용해 **오프라인 서버**로 옮깁니다.

### 2단계: 오프라인 서버에서 설치

1. **압축 해제**
   - 서버로 옮긴 파일의 압축을 풉니다.
   ```bash
   tar -xzvf offline_kit.tar.gz
   ```

2. **설치 스크립트 실행**
   - 압축 해제 후 생성된 폴더로 이동하여, `make install-offline` 명령을 실행합니다.
   - **주의**: `make` 명령 자체는 설치를 수행하지 않고, 실행해야 할 정확한 `sudo` 명령어를 안내해줍니다. 안내에 따라 명령어를 복사하여 실행하세요.
   ```bash
   cd ADD_infiniband_package # 또는 압축 해제 시 생성된 폴더명
   make install-offline
   ```
   - 스크립트가 커널 업데이트 후 재부팅을 요구하면, 재부팅 후 **반드시 새 커널로 부팅**해야 합니다.
   - 부팅이 완료되면, 다시 같은 폴더로 이동하여 동일한 설치 명령어를 실행하여 나머지 과정을 완료합니다.

---

## Makefile Targets 상세 설명

- `make all` 또는 `make help`: 사용 가능한 모든 `make` 타겟의 목록과 설명을 보여줍니다.
- `make download`: 의존성 패키지를 다운로드합니다. (`download_dependencies.sh` 실행)
- `make repo`: 로컬 저장소를 생성하고 전체 키트를 압축합니다. (`create_repo_archive.sh` 실행)
- `make install-online`: 온라인 PC에 직접 패키지를 설치합니다. (`install_online.sh` 실행)
- `make install-offline`: 오프라인 서버에서 설치를 진행하는 방법을 안내합니다.
- `make clean`: `debs` 폴더, `offline_kit.tar.gz` 등 생성된 파일들을 모두 삭제합니다.
