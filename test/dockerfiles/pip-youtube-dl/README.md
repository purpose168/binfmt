# 参考链接：https://github.com/docker/buildx/issues/584
# 这个链接指向 Docker Buildx 的 GitHub issue，讨论了相关的构建问题

# 源代码参考：https://gitlab.com/Lukas1818/docker-youtube-dl-cron/-/blob/f2ad34237db30046dcf9029aada5d588172e8032/Dockerfile
# 这个链接指向 GitLab 上的原始 Dockerfile，提供了实现参考

# 构建命令示例
# 使用 Docker Buildx 构建多平台镜像
# docker buildx build 是 BuildKit 的构建命令
# --platform linux/arm/v7 指定目标平台为 ARM v7 架构
# . 表示使用当前目录作为构建上下文
```console
$ docker buildx build --platform linux/arm/v7 .
```
