# 参考链接：https://github.com/moby/buildkit/issues/5783
# 这个链接指向 BuildKit 的一个 issue，讨论了相关的构建问题
# 使用 Debian 11 (bullseye 的精简版) 作为基础镜像
# bullseye-slim 是 Debian 11 的精简版本，体积更小，适合容器化部署
FROM debian:bullseye-slim

# 更新软件包列表并安装 curl 工具
# apt-get update 更新软件包索引，确保可以获取最新的软件包信息
# apt-get install -y 安装软件包，-y 参数表示自动确认安装，无需手动输入 yes
# curl 是一个命令行工具，用于传输数据，支持多种协议（HTTP、HTTPS、FTP 等）
RUN apt-get update && apt-get install -y curl
