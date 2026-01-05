# 指定 Dockerfile 语法版本
# docker/dockerfile:1-labs 使用 Dockerfile 实验性语法
# labs 版本包含最新的实验性功能，如 BuildKit 的高级特性
#syntax=docker/dockerfile:1-labs

# 第一阶段：使用 xx 跨平台构建工具
# --platform=$BUILDPLATFORM 使用构建平台（主机平台）
# tonistiigi/xx 是一个跨平台构建工具，用于简化多架构构建
# xx:1.1.1 指定工具版本为 1.1.1
# AS xx 将此阶段命名为 xx，后续可以通过 --from=xx 引用
FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.1.1 AS xx

# 第二阶段：源代码阶段
# FROM scratch 表示从空镜像开始
# scratch 是一个完全空的镜像，不包含任何文件
# AS src 将此阶段命名为 src
FROM scratch AS src
# 复制所有 .go 文件和 go.* 文件到根目录
# *.go 匹配所有 Go 源代码文件
# go.* 匹配 go.mod 和 go.sum 等 Go 模块文件
COPY *.go go.* /

# 第三阶段：构建阶段
# --platform=$BUILDPLATFORM 使用构建平台
# golang:1.18-alpine 使用 Go 1.18 的 Alpine Linux 版本
# Alpine Linux 是一个轻量级的 Linux 发行版，体积小
# AS build 将此阶段命名为 build
FROM --platform=$BUILDPLATFORM golang:1.18-alpine AS build
# 从 xx 阶段复制所有文件到根目录
# --from=xx 指定源阶段为 xx
COPY --from=xx / /
# 安装构建工具
# apk 是 Alpine Linux 的包管理器
# add 表示安装包
# clang 是 C/C++ 编译器前端
# lld 是 LLVM 链接器
# file 用于识别文件类型
RUN apk add clang lld file
# 定义构建参数 TARGETPLATFORM
# ARG 用于定义构建时的变量
# TARGETPLATFORM 是 Docker BuildKit 内置变量，表示目标平台
ARG TARGETPLATFORM
# 使用 xx 工具安装 musl 开发库和 Linux 头文件
# xx-apk 是 xx 工具提供的包管理命令
# musl-dev 是 musl C 库的开发文件
# linux-headers 是 Linux 内核头文件
# gcc 是 GNU C 编译器
RUN xx-apk add musl-dev linux-headers gcc
# 设置工作目录为 /src
# WORKDIR 指定容器内的工作目录
# 后续命令会在这个目录下执行
WORKDIR /src
# 设置 xx-clang 使用静态链接器
# XX_CC_PREFER_STATIC_LINKER=1 环境变量指示优先使用静态链接器
# xx-clang 是 xx 工具提供的交叉编译编译器
# --setup-target-triple 设置目标平台的三元组（如 arm-linux-musleabihf）
RUN XX_CC_PREFER_STATIC_LINKER=1 xx-clang --setup-target-triple
# 构建测试程序
# --mount=from=src 从 src 阶段挂载源代码
# --mount=type=cache,target=/root/.cache/go-build 挂载 Go 构建缓存
# --mount=type=cache,target=/go/pkg 挂载 Go 包缓存
# CGO_ENABLED=1 启用 CGO（允许 Go 调用 C 代码）
# xx-go 是 xx 工具提供的 Go 编译器
# test -c 编译测试程序
# -o /out/test 指定输出文件路径
# -ldflags "-linkmode external -extldflags -static" 设置链接器标志
#   -linkmode external 使用外部链接器
#   -extldflags -static 传递 -static 标志给外部链接器，生成静态链接的可执行文件
# . 表示当前目录（工作目录）
# xx-verify --static /out/test 验证生成的可执行文件是静态链接的
RUN --mount=from=src \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=1 xx-go test -c -o /out/test -ldflags "-linkmode external -extldflags -static" . && \
    xx-verify --static /out/test

# 第四阶段：二进制文件阶段
# FROM scratch 从空镜像开始
# AS binary 将此阶段命名为 binary
FROM scratch AS binary
# 从 build 阶段复制测试程序到根目录
# --from=build 指定源阶段为 build
COPY --from=build /out/test .

# 第五阶段：运行测试阶段
# alpine 使用 Alpine Linux 基础镜像
# AS run 将此阶段命名为 run
FROM alpine AS run
# 安装 libcap 库
# libcap 用于 Linux 能力（capabilities）管理
RUN apk add libcap
# 从 binary 阶段复制测试程序到 /usr/bin
# --from=binary 指定源阶段为 binary
COPY --from=binary / /usr/bin
# 定义构建参数 CONFIG_RT_GROUP_SCHED
# ARG 用于定义构建时的变量
# CONFIG_RT_GROUP_SCHED 可能与实时进程组调度相关
ARG CONFIG_RT_GROUP_SCHED
# 运行测试程序
# --security=insecure 允许不安全的操作（如需要特权）
# REEXEC_NAME=/usr/bin/test 设置重新执行的程序名称
# /usr/bin/test -test.v 运行测试并显示详细输出
RUN --security=insecure REEXEC_NAME=/usr/bin/test /usr/bin/test -test.v

# 最终阶段：从 binary 阶段开始
# FROM binary 使用 binary 阶段作为基础
# 这个阶段会生成最终的镜像，只包含静态链接的测试程序
FROM binary
