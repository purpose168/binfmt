# 语法声明：指定使用 Dockerfile 1.0 版本语法
# syntax=docker/dockerfile:1

# 定义 Go 语言版本参数，默认值为 1.23
ARG GO_VERSION=1.23

# 定义 Alpine Linux 版本参数，默认值为 3.21
ARG ALPINE_VERSION=3.21

# 基于指定版本的 Go 语言 Alpine 镜像构建
# Alpine 是一个轻量级的 Linux 发行版，适合容器化部署
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION}

# 使用 Alpine 包管理器安装 gcc 编译器和 musl-dev 开发库
# --no-cache 参数表示不缓存包索引，减小镜像体积
# gcc 是 C 语言编译器，某些 Go 包可能需要 CGO 支持
# musl-dev 是 Alpine 的 C 标准库开发文件
RUN apk add --no-cache gcc musl-dev

# 下载并安装 golangci-lint 代码检查工具
# wget -O- 表示将下载内容输出到标准输出
# -nv 参数表示关闭详细输出，只显示错误和基本信息
# sh -s v1.62.0 表示将下载的内容通过 shell 执行，并传递版本参数
# golangci-lint 是 Go 语言的代码静态分析工具，用于检查代码质量和潜在问题
RUN wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.62.0

# 设置工作目录为 Go 源代码路径
# 这是 binfmt 项目的标准 Go 源代码目录结构
WORKDIR /go/src/github.com/tonistiigi/binfmt

# 运行 golangci-lint 代码检查
# --mount=target=. 将当前目录挂载到容器内，用于代码检查
# --mount=target=/root/.cache,type=cache 挂载缓存目录，加速构建过程
# golangci-lint run 会检查项目中的所有 Go 代码，发现潜在问题
RUN --mount=target=. --mount=target=/root/.cache,type=cache \
  golangci-lint run
