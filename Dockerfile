# syntax=docker/dockerfile:1

# 定义构建参数：Go版本、Alpine版本和xx工具版本
ARG GO_VERSION=1.23
ARG ALPINE_VERSION=3.22
ARG XX_VERSION=1.7.0

# 定义QEMU参数：QEMU版本和仓库地址
ARG QEMU_VERSION=HEAD
ARG QEMU_REPO=https://github.com/qemu/qemu

# xx是用于交叉编译的辅助工具，提供跨平台编译支持
FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

# 源码准备阶段：克隆QEMU源码并应用补丁
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS src
# 安装必要的工具：git用于版本控制，patch用于应用补丁，meson用于构建系统
RUN apk add --no-cache git patch meson

WORKDIR /src
ARG QEMU_VERSION
ARG QEMU_REPO
# 克隆QEMU仓库并检出指定版本
RUN git clone $QEMU_REPO && cd qemu && git checkout $QEMU_VERSION
# 复制本地补丁文件到容器中
COPY patches patches
# QEMU_PATCHES定义编译前需要应用的额外补丁（默认应用cpu-max-arm补丁）
ARG QEMU_PATCHES=cpu-max-arm
# QEMU_PATCHES_ALL定义所有需要应用的补丁（包括默认补丁、Alpine补丁和meson补丁）
ARG QEMU_PATCHES_ALL=${QEMU_PATCHES},alpine-patches,meson
# QEMU_PRESERVE_ARGV0定义是否保留原始参数向量（用于设置二进制文件名）
ARG QEMU_PRESERVE_ARGV0
# 应用补丁的脚本：从Alpine仓库获取补丁并应用
RUN <<eof
  set -ex
  # 检查是否需要应用Alpine补丁
  if [ "${QEMU_PATCHES_ALL#*alpine-patches}" != "${QEMU_PATCHES_ALL}" ]; then
    ver="$(cat qemu/VERSION)"
    # 从aports.config中查找匹配的版本和对应的commit
    for l in $(cat patches/aports.config); do
      pver=$(echo $l | cut -d, -f1)
      if [ "${ver%.*}" = "${pver%.*}" ]; then
        commit=$(echo $l | cut -d, -f2)
        rmlist=$(echo $l | cut -d, -f3)
        break
      fi
    done
    # 克隆Alpine的aports仓库并获取QEMU补丁
    mkdir -p aports && cd aports && git init
    git fetch --depth 1 https://github.com/alpinelinux/aports.git "$commit"
    git checkout FETCH_HEAD
    mkdir -p ../patches/alpine-patches
    # 移除不需要的补丁文件
    for f in $(echo $rmlist | tr ";" "\n"); do
      rm community/qemu/*${f}*.patch || true
    done
    # 复制所有QEMU补丁到patches目录
    cp -a community/qemu/*.patch ../patches/alpine-patches/
    cd - && rm -rf aports
  fi
  # 如果需要保留argv0，则添加preserve-argv0补丁
  if [ -n "${QEMU_PRESERVE_ARGV0}" ]; then
    QEMU_PATCHES_ALL="${QEMU_PATCHES_ALL},preserve-argv0"
  fi
  # 应用所有指定的补丁
  cd qemu
  for p in $(echo $QEMU_PATCHES_ALL | tr ',' '\n'); do
    for f in  ../patches/$p/*.patch; do echo "apply $f"; patch -p1 < $f; done
  done
eof
# 更新QEMU子模块并下载依赖项目
RUN <<eof
  set -ex
  cd qemu
  # 初始化并更新子模块（参考QEMU官方发布脚本）
  # https://github.com/qemu/qemu/blob/ed734377ab3f3f3cc15d7aa301a87ab6370f2eed/scripts/make-release#L56-L57
  git submodule update --init --single-branch
  # 下载meson子项目依赖：keycodemapdb（键盘映射）、berkeley-testfloat-3（测试浮点库）、berkeley-softfloat-3（软浮点库）、dtc（设备树编译器）、slirp（用户态网络）
  meson subprojects download keycodemapdb berkeley-testfloat-3 berkeley-softfloat-3 dtc slirp
eof

# 基础构建环境：安装编译QEMU所需的工具和依赖
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS base
# 安装编译工具链和依赖：git（版本控制）、clang（C编译器）、lld（链接器）、python3（构建脚本）、llvm（LLVM工具链）、make（构建工具）、ninja（快速构建工具）、pkgconfig（包配置工具）、glib-dev（GLib开发库）、gcc（GCC编译器）、musl-dev（musl libc开发库）、pcre2-dev（PCRE2正则表达式库）、perl（Perl解释器）、bash（Shell）
RUN apk add --no-cache git clang lld python3 llvm make ninja pkgconfig glib-dev gcc musl-dev pcre2-dev perl bash
# 复制xx工具到容器中
COPY --from=xx / /
# 设置环境变量，将qemu安装脚本目录添加到PATH
ENV PATH=/qemu/install-scripts:$PATH
WORKDIR /qemu

ARG TARGETPLATFORM
# 为交叉编译平台安装必要的开发包：musl-dev（musl libc）、gcc（GCC编译器）、glib-dev（GLib开发库）、glib-static（GLib静态库）、linux-headers（Linux内核头文件）、pcre2-dev（PCRE2开发库）、pcre2-static（PCRE2静态库）、zlib-static（zlib静态库）
RUN xx-apk add --no-cache musl-dev gcc glib-dev glib-static linux-headers pcre2-dev pcre2-static zlib-static
# 针对特定架构设置编译器链接器（ppc64le和386架构需要特殊处理）
RUN set -e; \
  [ "$(xx-info arch)" = "ppc64le" ] && XX_CC_PREFER_LINKER=ld xx-clang --setup-target-triple; \
  [ "$(xx-info arch)" = "386" ] && XX_CC_PREFER_LINKER=ld xx-clang --setup-target-triple; \
  true

# 编译QEMU阶段：使用源码构建QEMU模拟器
FROM base AS build
ARG TARGETPLATFORM
# QEMU_TARGETS设置要为哪些架构构建模拟器（默认为全部）
ARG QEMU_VERSION QEMU_TARGETS
# 设置归档工具为llvm-ar，剥离工具为llvm-strip
ENV AR=llvm-ar STRIP=llvm-strip
# 编译并安装QEMU，然后验证二进制文件
RUN --mount=target=.,from=src,src=/src/qemu,rw --mount=target=./install-scripts,src=scripts \
  echo ${TARGETPLATFORM} && \
  TARGETPLATFORM=${TARGETPLATFORM} configure_qemu.sh && \
  make -j "$(getconf _NPROCESSORS_ONLN)" && \
  make install && \
  cd /usr/bin && for f in $(ls qemu-*); do xx-verify --static $f; done

# 为二进制文件添加前缀（如果指定了BINARY_PREFIX）
ARG BINARY_PREFIX
RUN cd /usr/bin; [ -z "$BINARY_PREFIX" ] || for f in $(ls qemu-*); do ln -s $f $BINARY_PREFIX$f; done

# 创建QEMU二进制文件的压缩包
FROM build AS build-archive-run
RUN cd /usr/bin && mkdir -p /archive && \
  tar czvfh "/archive/${BINARY_PREFIX}qemu_${QEMU_VERSION}_$(echo $TARGETPLATFORM | sed 's/\//-/g').tar.gz" ${BINARY_PREFIX}qemu*

# 从构建结果中提取压缩包
FROM scratch AS build-archive
COPY --from=build-archive-run /archive/* /

# 构建binfmt二进制文件：编译binfmt管理工具
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS binfmt
# 复制xx工具到容器中
COPY --from=xx / /
# 禁用CGO以生成静态二进制文件
ENV CGO_ENABLED=0
ARG TARGETPLATFORM
ARG QEMU_VERSION
WORKDIR /src
# 安装git用于获取版本信息
RUN apk add --no-cache git
# 编译binfmt工具，嵌入版本信息
RUN --mount=target=. \
  TARGETPLATFORM=$TARGETPLATFORM xx-go build \
    -ldflags "-X main.revision=$(git rev-parse --short HEAD) -X main.qemuVersion=${QEMU_VERSION}" \
    -o /go/bin/binfmt ./cmd/binfmt && \
    xx-verify --static /go/bin/binfmt

# 创建binfmt二进制文件的压缩包
FROM build AS binfmt-archive-run
COPY --from=binfmt /go/bin/binfmt /usr/bin/binfmt
RUN cd /usr/bin && mkdir -p /archive && \
  tar czvfh "/archive/binfmt_$(echo $TARGETPLATFORM | sed 's/\//-/g').tar.gz" binfmt

# 从构建结果中提取binfmt压缩包
FROM scratch AS binfmt-archive
COPY --from=binfmt-archive-run /archive/* /

# binaries阶段：仅包含编译好的QEMU二进制文件
FROM scratch AS binaries
# BINARY_PREFIX为所有QEMU二进制文件设置前缀字符串
ARG BINARY_PREFIX
COPY --from=build usr/bin/${BINARY_PREFIX}qemu-* /

# archive阶段：返回构建和binfmt的tarball
FROM scratch AS archive
COPY --from=build-archive / /
COPY --from=binfmt-archive / /

# 用于测试的断言工具（bats-assert）
FROM --platform=$BUILDPLATFORM tonistiigi/bats-assert AS assert

# 用于跨架构测试的Alpine环境
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS alpine-crossarch

# 安装bash用于执行测试脚本
RUN apk add --no-cache bash

# 在构建平台上运行但不使用模拟，我们需要获取跨架构的busybox二进制文件
# 用于使用模拟的测试
ARG BUILDARCH
# 根据构建架构设置apk架构，以便下载对应架构的busybox
RUN <<eof
  bash -euo pipefail -c '
    if [ "$BUILDARCH" == "amd64" ]; then
      echo "aarch64" > /etc/apk/arch
    else
      echo "x86_64" > /etc/apk/arch
    fi
    '
eof
# 安装跨架构的busybox静态二进制文件
RUN apk add --allow-untrusted --no-cache busybox-static

# 重新创建由busybox多调用二进制文件处理的所有符号链接，使其使用
# 跨架构二进制文件，并在模拟下工作
RUN <<eof
  bash -euo pipefail -c '
    mkdir -p /crossarch/bin /crossarch/usr/bin
    mv /bin/busybox.static /crossarch/bin/
    for i in $(echo /bin/*; echo /usr/bin/*); do
     if [[ $(readlink -f "$i") != *busybox* ]]; then
       continue
     fi
     ln -s /crossarch/bin/busybox.static /crossarch$i
    done'
eof

# buildkit-test阶段：运行buildkit嵌入式QEMU的测试套件
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS buildkit-test
# 安装bash和bats测试框架
RUN apk add --no-cache bash bats
WORKDIR /work
# 复制测试断言工具
COPY --from=assert . .
# 复制测试文件
COPY test .
# 复制编译好的QEMU二进制文件
COPY --from=binaries / /usr/bin
# 复制跨架构busybox
COPY --from=alpine-crossarch /crossarch /crossarch/
# 运行测试脚本
RUN ./run.sh

# image阶段：构建binfmt安装镜像
FROM scratch AS image
# 复制QEMU二进制文件到镜像
COPY --from=binaries / /usr/bin/
# 复制binfmt工具到镜像
COPY --from=binfmt /go/bin/binfmt /usr/bin/binfmt
# QEMU_PRESERVE_ARGV0定义是否使用argv0设置二进制文件名
ARG QEMU_PRESERVE_ARGV0
ENV QEMU_PRESERVE_ARGV0=${QEMU_PRESERVE_ARGV0}
# 设置入口点为binfmt工具
ENTRYPOINT [ "/usr/bin/binfmt" ]
# 创建/tmp卷用于临时文件
VOLUME /tmp
