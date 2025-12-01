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
   ```
3. `make` 명령어를 실행하면 `.env` 파일에 설정된 값을 기준으로 작업을 수행합니다. `make help` 명령어로 현재 적용된 설정을 확인할 수 있습니다.

---

## 사용 방법 (`Makefile` 사용)

`Makefile`을 사용하면 전체 과정을 단계별로 명확하게 처리할 수 있습니다.

### 1단계: 온라인 PC에서 설치 키트 생성 및 테스트

1. **의존성 패키지 다운로드**
   - Lustre/OFED 설치에 필요한 모든 `.deb` 패키지를 다운로드합니다.
   ```bash
   make download
   ```

2. **로컬 저장소 생성**
   - 다운로드된 패키지 폴더를 `apt`가 인식할 수 있는 로컬 저장소로 만듭니다.
   ```bash
   make local-repo
   ```

3. **(선택) 시스템 저장소로 설치 및 APT 소스 추가**
   - 생성된 로컬 저장소를 현재 PC의 시스템 경로(`${REPO_PATH}`)에 '설치'하고, `apt`가 이 저장소를 사용하도록 설정합니다.
   - 이 단계를 통해, 오프라인 서버에 배포하기 전 온라인 PC에서 생성된 저장소가 정상인지 테스트할 수 있습니다.
   ```bash
   make add-local-repo
   ```

4. **오프라인용 아카이브 생성**
   - 오프라인 서버에 배포하기 위해, `local-repo` 단계까지 완료된 프로젝트를 `.tar.gz` 파일로 압축합니다.
   ```bash
   make repo
   ```

5. **파일 전송**
   - 생성된 `${ARCHIVE_NAME}` 파일을 USB 등의 매체를 이용해 **오프라인 서버**로 옮깁니다.

### 2단계: 오프라인 서버에서 설치

1. **압축 해제**
   - 서버로 옮긴 파일의 압축을 풉니다.
   ```bash
   tar -xzvf <ARCHIVE_NAME>
   ```

2. **설치 스크립트 실행**
   - 압축 해제 후 생성된 폴더로 이동하여, `make install-offline` 명령으로 안내를 확인하고, 안내된 `sudo` 명령어를 실행합니다.
   ```bash
   cd <압축 해제된 폴더명>
   make install-offline
   ```
   - 스크립트가 커널 업데이트 후 재부팅을 요구하면, 재부팅 후 **반드시 새 커널로 부팅**해야 합니다.
   - 부팅이 완료되면, 다시 같은 폴더로 이동하여 동일한 설치 명령어를 실행하여 나머지 과정을 완료합니다.

---

## Makefile Targets 상세 설명

- `make download`: [1단계] 모든 의존성 `.deb` 패키지를 다운로드합니다.
- `make local-repo`: [2단계] 다운로드된 폴더를 로컬 APT 저장소로 만듭니다.
- `make install-repo`: [3단계] 로컬 저장소를 시스템 경로(`${REPO_PATH}`)에 설치하고 권한을 설정합니다.
- `make add-local-repo`: [4단계] 시스템에 설치된 저장소를 현재 PC의 `apt` 소스에 추가합니다. (`install-repo` 포함)
- `make repo`: `local-repo` 완료 후, 오프라인 배포를 위해 전체 폴더를 압축합니다.
- `make clean`: 생성된 모든 빌드 결과물, 시스템 저장소, `apt` 소스 리스트를 삭제합니다.
- `make install-online`: 온라인 환경에서 패키지를 직접 설치합니다.
- `make install-offline`: 오프라인 환경에서 설치하는 방법을 안내합니다.
- `make help`: 사용 가능한 모든 타겟 목록과 현재 설정을 보여줍니다.
