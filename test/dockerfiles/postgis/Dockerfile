# 使用 PostGIS 15 的 master 分支版本作为基础镜像
# PostGIS 是 PostgreSQL 的空间数据库扩展
# postgis/postgis:15-master 包含了 PostgreSQL 15 和 PostGIS 的最新开发版本
FROM postgis/postgis:15-master

# 设置 QEMU_STRACE 环境变量为空字符串
# ENV 用于设置容器内的环境变量
# QEMU_STRACE 可能用于控制 QEMU 模拟器的调试行为
# 设置为空表示禁用 strace 跟踪
ENV QEMU_STRACE=""

# 设置 PostgreSQL 数据库的密码
# POSTGRES_PASSWORD 是 PostgreSQL 官方镜像的环境变量
# password 是数据库的超级用户密码
# 在生产环境中应该使用更安全的密码，并通过 secrets 或环境变量传递
ENV POSTGRES_PASSWORD=password
