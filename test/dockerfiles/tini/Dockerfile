# 语法声明：指定使用 Dockerfile 1.0 版本语法
# syntax=docker/dockerfile:1

# 定义 Tini 版本参数，默认值为 v0.19.0
# ARG 用于定义构建时的参数，可以在构建时传递
# TINI_VERSION 指定要下载的 tini 版本
ARG TINI_VERSION="v0.19.0"

# 使用 Alpine 3.17 作为基础镜像
# Alpine 是一个轻量级的 Linux 发行版，适合容器化部署
FROM alpine:3.17

# 安装必要的工具
# apk add 是 Alpine 的包管理器命令
# --no-cache 参数表示不缓存包索引，减小镜像体积
# file 是文件类型检测工具
# wget 是命令行下载工具
RUN apk add --no-cache file wget

# 声明构建参数，使其在后续指令中可用
# TINI_VERSION 是 tini 的版本号
ARG TINI_VERSION

# TARGETPLATFORM 是 Docker BuildKit 提供的内置变量
# 表示构建的目标平台，例如 linux/amd64、linux/arm64 等
ARG TARGETPLATFORM

# 使用 heredoc 语法执行多行脚本
# EOT 是开始和结束标记
RUN <<EOT
  # 根据目标平台确定 tini 的架构名称
  # case 语句根据 TARGETPLATFORM 的值输出对应的架构
  TINI_ARCH=$(case ${TARGETPLATFORM} in
    # AMD64 架构（x86_64）
    "linux/amd64")   echo "amd64"   ;;
    # ARM v6 架构（32位）
    "linux/arm/v6")  echo "armel"   ;;
    # ARM v7 架构（32位）
    "linux/arm/v7")  echo "armhf"   ;;
    # ARM64 架构（64位）
    "linux/arm64")   echo "arm64"   ;;
    # PowerPC 64位小端序架构
    "linux/ppc64le") echo "ppc64le" ;;
    # IBM System z 64位架构
    "linux/s390x")   echo "390x"    ;;
    # 其他架构输出空字符串
    *)               echo ""        ;; esac)
  
  # 从 GitHub 下载对应架构的静态链接 tini 二进制文件
  # wget -q 安静模式，不显示下载进度
  # -qO /tini 将下载内容输出到 /tini 文件
  # URL 格式：https://github.com/krallin/tini/releases/download/{version}/tini-static-{arch}
  wget -q "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TINI_ARCH}" -qO /tini
  
  # 设置 tini 文件为可执行
  # chmod +x 添加执行权限
  chmod +x /tini
  
  # 使用 file 命令检查 tini 文件类型
  # 这可以验证下载的二进制文件是否正确
  file /tini
EOT

# 设置 QEMU_STRACE 环境变量为空字符串
# ENV 用于设置容器内的环境变量
# QEMU_STRACE 可能用于控制 QEMU 模拟器的调试行为
# 设置为空表示禁用 strace 跟踪
ENV QEMU_STRACE=""

# 设置容器启动时的默认命令
# CMD 指定容器启动时执行的命令
# ["/tini", "-s", "--", "uname", "-a"] 的含义：
# /tini：运行 tini 程序
# -s：使用 subreaper 模式，确保正确回收子进程
# --：分隔符，表示后面的参数是要执行的命令
# uname -a：显示系统信息，用于测试容器是否正常运行
CMD [ "/tini", "-s", "--", "uname", "-a" ]
