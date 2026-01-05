# 语法声明：指定使用 Dockerfile 1.0 版本语法
# syntax=docker/dockerfile:1

# 定义 Go 语言版本参数，默认值为 1.23
ARG GO_VERSION=1.23

# 定义 Alpine Linux 版本参数，默认值为 3.21
ARG ALPINE_VERSION=3.21

# 第一阶段：构建 vendored 镜像
# 使用 AS 关键字为这个构建阶段命名，便于后续引用
# 基于指定版本的 Go 语言 Alpine 镜像构建
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS vendored

# 安装 Git 版本控制系统
# --no-cache 参数表示不缓存包索引，减小镜像体积
# Git 用于下载和管理 Go 模块的依赖
RUN  apk add --no-cache git

# 设置工作目录为 /src
# 这是源代码存放的目录
WORKDIR /src

# 执行 Go 模块依赖管理命令
# --mount=target=/src,rw 将当前目录以读写模式挂载到容器的 /src 目录
# --mount=target=/go/pkg/mod,type=cache 挂载 Go 模块缓存目录，加速依赖下载
# go mod tidy 整理依赖关系，确保 go.mod 和 go.sum 文件的一致性
# go mod vendor 将依赖复制到 vendor 目录，实现依赖本地化
# mkdir /out 创建输出目录
# cp -r go.mod go.sum vendor /out 将模块文件和 vendor 目录复制到输出目录
RUN --mount=target=/src,rw \
  --mount=target=/go/pkg/mod,type=cache \
  go mod tidy && go mod vendor && \
  mkdir /out && cp -r go.mod go.sum vendor /out

# 第二阶段：构建 update 镜像
# FROM scratch 表示从空镜像开始，这是最小的基础镜像
# 这个阶段用于更新 vendor 依赖文件
FROM scratch AS update

# 从 vendored 阶段复制输出目录的内容到根目录
# --from=vendored 指定源构建阶段
# /out/ 是源阶段的输出目录
# / 是目标镜像的根目录
COPY --from=vendored /out /

# 第三阶段：构建 validate 镜像
# 基于第一阶段的 vendored 镜像构建
# 这个阶段用于验证 vendor 依赖的正确性
FROM vendored AS validate

# 执行 vendor 验证命令
# --mount=target=.,rw 将当前目录以读写模式挂载到容器
# git add -A 将所有更改添加到 Git 暂存区
# rm -rf vendor 删除本地的 vendor 目录
# cp -rf /out/* . 将更新后的依赖文件从 /out 复制到当前目录
# ./hack/validate-vendor check 运行验证脚本检查 vendor 依赖是否正确
RUN --mount=target=.,rw \
  git add -A && \
  rm -rf vendor && \
  cp -rf /out/* . && \
  ./hack/validate-vendor check
