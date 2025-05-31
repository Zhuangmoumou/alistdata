# Toolchain Configuration
TARGET := aarch64-linux-gnu
TOOLCHAIN_PREFIX := /builder/arm64-toolchain
GCC_VERSION := 8.5.0
BINUTILS_VERSION := 2.30
GLIBC_VERSION := 2.27
JOBS := $(shell nproc)

# Source URLs (使用国内镜像加速)
GCC_SOURCE := https://mirrors.ustc.edu.cn/gnu/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.xz
BINUTILS_SOURCE := https://mirrors.ustc.edu.cn/gnu/binutils/binutils-$(BINUTILS_VERSION).tar.xz
GLIBC_SOURCE := https://mirrors.ustc.edu.cn/gnu/glibc/glibc-$(GLIBC_VERSION).tar.xz

# 静默模式控制 (兼容 GitHub Actions 日志)
Q := @
ifndef VERBOSE
.SILENT:
endif

.PHONY: all clean

all: binutils gcc-stage1 glibc gcc-stage2

# 下载源码（自动重试）
download-sources:
	$(Q)for pkg in gcc binutils glibc; do \
		if [ ! -d "$${pkg}-$($(shell echo $${pkg} | tr 'a-z' 'A-Z')_VERSION)" ]; then \
			wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 -O $${pkg}-$($(shell echo $${pkg} | tr 'a-z' 'A-Z')_VERSION).tar.xz $($(shell echo $${pkg} | tr 'a-z' 'A-Z')_SOURCE) && \
			tar xf $${pkg}-$($(shell echo $${pkg} | tr 'a-z' 'A-Z')_VERSION).tar.xz || exit 1; \
		fi \
	done

# 编译 binutils
binutils: download-sources
	$(Q)echo "[1/4] Building binutils..."
	$(Q)mkdir -p build-binutils && cd build-binutils && \
	../binutils-$(BINUTILS_VERSION)/configure \
		--prefix=$(TOOLCHAIN_PREFIX) \
		--target=$(TARGET) \
		--disable-multilib \
		--disable-werror > ../binutils.log 2>&1 && \
	$(MAKE) -j$(JOBS) >> ../binutils.log 2>&1 && \
	sudo $(MAKE) install >> ../binutils.log 2>&1

# 编译 GCC (第一阶段)
gcc-stage1: binutils
	$(Q)echo "[2/4] Building GCC (Stage 1)..."
	$(Q)mkdir -p build-gcc-stage1 && cd build-gcc-stage1 && \
	../gcc-$(GCC_VERSION)/configure \
		--prefix=$(TOOLCHAIN_PREFIX) \
		--target=$(TARGET) \
		--enable-languages=c \
		--disable-multilib \
		--without-headers \
		--disable-bootstrap > ../gcc-stage1.log 2>&1 && \
	$(MAKE) -j$(JOBS) all-gcc >> ../gcc-stage1.log 2>&1 && \
	sudo $(MAKE) install-gcc >> ../gcc-stage1.log 2>&1

# 编译 glibc
glibc: gcc-stage1
	$(Q)echo "[3/4] Building glibc..."
	$(Q)mkdir -p build-glibc && cd build-glibc && \
	../glibc-$(GLIBC_VERSION)/configure \
		--prefix=$(TOOLCHAIN_PREFIX)/$(TARGET) \
		--build=x86_64-linux-gnu \
		--host=$(TARGET) \
		--target=$(TARGET) \
		--with-headers=$(TOOLCHAIN_PREFIX)/$(TARGET)/include \
		--disable-multilib \
		--disable-werror > ../glibc.log 2>&1 && \
	$(MAKE) -j$(JOBS) >> ../glibc.log 2>&1 && \
	sudo $(MAKE) install >> ../glibc.log 2>&1

# 编译完整 GCC (第二阶段)
gcc-stage2: glibc
	$(Q)echo "[4/4] Building GCC (Stage 2)..."
	$(Q)mkdir -p build-gcc-stage2 && cd build-gcc-stage2 && \
	../gcc-$(GCC_VERSION)/configure \
		--prefix=$(TOOLCHAIN_PREFIX) \
		--target=$(TARGET) \
		--enable-languages=c,c++ \
		--disable-multilib \
		--with-sysroot=$(TOOLCHAIN_PREFIX)/$(TARGET) \
		--disable-bootstrap > ../gcc-stage2.log 2>&1 && \
	$(MAKE) -j$(JOBS) >> ../gcc-stage2.log 2>&1 && \
	sudo $(MAKE) install >> ../gcc-stage2.log 2>&1

# 清理所有构建文件
clean:
	$(Q)echo "Cleaning all build artifacts..."
	$(Q)sudo rm -rf \
		gcc-$(GCC_VERSION)* \
		binutils-$(BINUTILS_VERSION)* \
		glibc-$(GLIBC_VERSION)* \
		build-* \
		*.log \
		$(TOOLCHAIN_PREFIX)
