# 使用 Python 3.9 的 Alpine 版本作为基础镜像
# Alpine 是一个轻量级的 Linux 发行版，适合容器化部署
# python:3.9-alpine 包含了 Python 3.9 运行时环境
FROM python:3.9-alpine

# 设置维护者信息
# MAINTAINER 指定镜像的维护者
# kev 是维护者名称
# noreply@easypi.pro 是联系邮箱
MAINTAINER kev <noreply@easypi.pro>

# 安装必要的软件包
# apk add 是 Alpine 的包管理器命令
# --no-cache 参数表示不缓存包索引，减小镜像体积
# ca-certificates 是 CA 证书包，用于 HTTPS 连接
# ffmpeg 是多媒体处理工具，youtube-dl 下载视频时需要
# openssl 是加密工具库
# aria2 是多线程下载工具，可以加速下载
RUN apk add --no-cache ca-certificates ffmpeg openssl aria2

# 定义构建参数 QEMU_STRACE
# ARG 用于定义构建时的参数，可以在构建时传递
# QEMU_STRACE 可能用于调试 QEMU 模拟器
ARG QEMU_STRACE

# 安装 youtube-dl 工具
# pip3 是 Python 3 的包管理器
# install 命令安装指定的 Python 包
# youtube-dl 是一个流行的视频下载工具
RUN pip3 install youtube-dl

# 测试 youtube-dl 是否正常工作
# 运行 youtube-dl --version 命令显示版本信息
# 这可以验证安装是否成功
RUN youtube-dl --version

# 设置工作目录为 /data
# WORKDIR 指定容器内的工作目录
# 后续命令会在这个目录下执行
WORKDIR /data

# 设置容器的入口点
# ENTRYPOINT 指定容器启动时执行的命令
# ["youtube-dl"] 表示使用 youtube-dl 作为主程序
ENTRYPOINT ["youtube-dl"]

# 设置默认命令
# CMD 指定容器启动时的默认参数
# ["--help"] 表示默认显示帮助信息
# 如果运行容器时没有提供参数，则显示帮助
CMD ["--help"]
