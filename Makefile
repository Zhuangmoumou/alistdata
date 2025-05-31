# Toolchain Configuration
TARGET := aarch64-linux-gnu
TOOLCHAIN_PREFIX := /builder/arm64-toolchain
GCC_VERSION := 8.5.0
BINUTILS_VERSION := 2.30
GLIBC_VERSION := 2.27
JOBS := $(shell nproc)

# 官方 GNU 源（无加速镜像）
GCC_SOURCE := https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.xz
BINUTILS_SOURCE := https://ftp.gnu.org/gnu/binutils/binutils-$(BINUTILS_VERSION).tar.xz
GLIBC_SOURCE := https://ftp.gnu.org/gnu/glibc/glibc-$(GLIBC_VERSION).tar.xz

.PHONY: all clean

all: binutils gcc-stage1 glibc gcc-stage2

# 修复的下载逻辑（强制校验URL）
download-sources:
	@echo "Downloading sources from GNU official mirrors..."
	@for pkg in gcc binutils glibc; do \
		case $$pkg in \
			gcc) url="$(GCC_SOURCE)"; version="$(GCC_VERSION)";; \
			binutils) url="$(BINUTILS_SOURCE)"; version="$(BINUTILS_VERSION)";; \
			glibc) url="$(GLIBC_SOURCE)"; version="$(GLIBC_VERSION)";; \
		esac; \
		if [ ! -f "$${pkg}-$${version}.tar.xz" ]; then \
			echo "Downloading $${url}..."; \
			wget --tries=3 --retry-connrefused --timeout=30 --waitretry=15 -O "$${pkg}-$${version}.tar.xz" "$${url}" || exit 1; \
		fi; \
		if [ ! -d "$${pkg}-$${version}" ]; then \
			tar xf "$${pkg}-$${version}.tar.xz" || (rm -f "$${pkg}-$${version}.tar.xz"; exit 1); \
		fi; \
	done

# 编译 binutils
binutils: download-sources
	@echo "[1/4] Building binutils..."
	@mkdir -p build-binutils && cd build-binutils && \
	../binutils-$(BINUTILS_VERSION)/configure \
		--prefix=$(TOOLCHAIN_PREFIX) \
		--target=$(TARGET) \
		--disable-multilib > ../binutils.log 2>&1 && \
	$(MAKE) -j$(JOBS) >> ../binutils.log 2>&1 && \
	sudo $(MAKE) install >> ../binutils.log 2>&1

# 其他编译阶段保持不变...
# （保持原有的 gcc-stage1, glibc, gcc-stage2 目标）

clean:
	@sudo rm -rf \
		gcc-$(GCC_VERSION)* \
		binutils-$(BINUTILS_VERSION)* \
		glibc-$(GLIBC_VERSION)* \
		build-* \
		*.log \
		$(TOOLCHAIN_PREFIX)
