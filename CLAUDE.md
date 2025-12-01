# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Lustre client and Mellanox OFED driver offline installation kit builder for Ubuntu 22.04 servers. The project creates complete package bundles with all dependencies for deploying in air-gapped environments.

**Core Purpose**: Download dependencies on an online PC, package them into an offline-installable archive, and install Lustre client + OFED drivers on offline servers.

## Key Commands

### Configuration
- Copy `.env.example` to `.env` and modify settings to override defaults
- Configuration variables: `TARGET_KERNEL`, `DEBS_DIR`, `ARCHIVE_NAME`, `REPO_PATH`, `OFED_DIR`
- View current configuration: `make help`

### Workflow A: Build from scratch (online PC)
1. `make download` - Download all .deb packages and dependencies recursively
2. `make repo` - Create offline deployment archive (`offline_kit.tar.gz`)
3. `make add-local-repo` - (Testing only) Install packages to system repository and add to APT sources

### Workflow B: Use existing .deb files
1. Place existing .deb files in `${DEBS_DIR}` directory (default: `debs/`)
2. `make repo` - Package existing files into deployment archive
3. `make add-local-repo` - (Testing only) Install to system repository

### Offline server installation
1. Extract archive: `tar -xzvf offline_kit.tar.gz`
2. Navigate to extracted directory
3. Run: `sudo ./install_offline_advanced.sh`
4. If kernel mismatch detected, reboot into target kernel and re-run script

### Other commands
- `make install-online` - Direct online installation (internet required)
- `make clean` - Remove all generated files, system repositories, and APT sources

## Architecture

### Two-Phase Installation Model
1. **Build Phase** (online PC): Download dependencies → Create local APT repository → Package into archive
2. **Deploy Phase** (offline server): Extract archive → Register local repo → Install kernel → Install OFED → Build Lustre client

### Script Organization

**Download & Repository Creation:**
- `download_dependencies.sh` - Uses `apt-rdepends` to recursively fetch all package dependencies including kernel packages, build tools, and Lustre client packages
- `create_local_repo.sh` - Generates `Packages.gz` index from .deb files in `${DEBS_DIR}`
- `create_repo_archive.sh` - Creates distributable `.tar.gz` archive

**Repository Installation:**
- `install_local_repo.sh` - Copies local repository to system path (`${REPO_PATH}`) with proper `_apt` user permissions
- `add_local_repo_to_sources.sh` - Adds system repository to `/etc/apt/sources.list.d/` and runs `apt-get update`

**Installation Scripts:**
- `install_online.sh` - Simple online installation via internet
- `install_offline_advanced.sh` - **Primary deployment script** for offline environments

### install_offline_advanced.sh Workflow

This script orchestrates the complete offline installation in 6 steps:

1. **setup_local_repo()**: Registers `debs/` directory as APT source using `file:` protocol
2. **check_and_install_kernel()**: Compares `uname -r` vs `TARGET_KERNEL`, installs kernel if needed, configures GRUB, prompts for reboot
3. **install_dependencies()**: Installs build tools (gcc, make, dkms), Lustre packages (lustre-source, lustre-client-utils), and libraries
4. **install_ofed()**: Locates OFED directory (via `OFED_DIR` env var or auto-detection of `MLNX_OFED_LINUX-*.tgz`), runs `./mlnxofedinstall --without-fw-update --force`, restarts openibd service
5. **build_lustre()**: Extracts `/usr/src/lustre.tar.bz2`, runs `./configure --with-linux=/usr/src/linux-headers-${TARGET_KERNEL} --disable-server`, builds with `make -j$(nproc)`, installs with `make install`
6. **verify_installation()**: Loads lustre kernel module and verifies with `lsmod`

**Stateful Execution**: Script is idempotent and can be re-run after kernel reboot. Checks current kernel version before proceeding.

## Important Implementation Details

### OFED Driver Handling
- Expects `MLNX_OFED_LINUX-*.tgz` file in project root (not tracked in git)
- Can specify exact OFED directory via `OFED_DIR` in `.env` to skip auto-detection
- Auto-detection pattern: `find . -maxdepth 1 -name "MLNX_OFED_LINUX-*.tgz"`

### Kernel Version Management
- Target kernel must match between build and deployment systems
- GRUB configuration is modified to show menu with 10-second timeout on offline server
- Kernel packages required: `linux-image-*`, `linux-headers-*`, `linux-modules-*`, `linux-modules-extra-*`

### APT Repository Structure
- Local repositories use `deb [trusted=yes]` to bypass GPG signature checks
- Repository index generated with: `dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz`
- File-based repository format: `deb [trusted=yes] file:/path/to/debs/ ./`

### Makefile Dependency Chain
- `add-local-repo` depends on `install-repo` depends on `local-repo`
- `repo` depends only on `local-repo` (for creating archive)
- `download` is standalone and not automatically invoked by other targets

## Development Notes

- All scripts use `set -e` for fail-fast behavior
- Color-coded output: RED for errors, YELLOW for progress, GREEN for success
- Root/sudo privilege required for most operations
- Scripts expect to be run from project root directory
