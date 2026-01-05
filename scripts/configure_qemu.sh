#!/usr/bin/env sh

# 设置 shell 选项
# -e 遇到错误立即退出
set -e

# 设置 QEMU_TARGETS 环境变量的默认值为空
# : 命令是 shell 内置命令，不执行任何操作
# ${QEMU_TARGETS=} 表示如果 QEMU_TARGETS 未设置，则设置为空字符串
# QEMU_TARGETS 用于指定要编译的 QEMU 目标架构列表
: "${QEMU_TARGETS=}"

# 获取当前系统架构
# xx-info 是一个工具，用于获取交叉编译信息
# arch 参数表示获取架构信息
arch="$(xx-info arch)"

# 检查 QEMU_TARGETS 是否为空
# 如果为空，则根据当前架构自动确定要编译的目标
if [ -z "$QEMU_TARGETS" ]; then
  # 使用 case 语句根据不同架构设置目标列表
  case "$arch" in
    # 32 位架构（386 和 arm）的特殊处理
    386|arm)
      # 从 QEMU 10.0 版本开始，已禁用在 32 位主机上配置 64 位客户机
      # 参考文档：https://www.qemu.org/docs/master/about/removed-features.html#bit-hosts-for-64-bit-guests-removed-in-10-0
      # 如果当前架构不是 386，则添加 i386-linux-user 目标
      if [ "$arch" != "386" ] ; then
        QEMU_TARGETS="$QEMU_TARGETS i386-linux-user"
      fi
      # 如果当前架构不是 arm，则添加 arm-linux-user 目标
      if [ "$arch" != "arm" ] ; then
        QEMU_TARGETS="$QEMU_TARGETS arm-linux-user"
      fi
      ;;
    # 其他架构（主要是 64 位架构）的处理
    *)
      # 如果当前架构不是 amd64，则添加 x86_64-linux-user 目标
      if [ "$arch" != "amd64" ]; then
        QEMU_TARGETS="$QEMU_TARGETS x86_64-linux-user"
      fi
      # 如果当前架构不是 arm64，则添加 aarch64-linux-user 目标
      if [ "$arch" != "arm64" ]; then
        QEMU_TARGETS="$QEMU_TARGETS aarch64-linux-user"
      fi
      # 如果当前架构不是 arm，则添加 arm-linux-user 目标
      if [ "$arch" != "arm" ]; then
        QEMU_TARGETS="$QEMU_TARGETS arm-linux-user"
      fi
      # 如果当前架构不是 riscv64，则添加 riscv64-linux-user 目标
      if [ "$arch" != "riscv64" ]; then
        QEMU_TARGETS="$QEMU_TARGETS riscv64-linux-user"
      fi
      # 如果当前架构不是 ppc64le，则添加 ppc64le-linux-user 目标
      if [ "$arch" != "ppc64le" ]; then
        QEMU_TARGETS="$QEMU_TARGETS ppc64le-linux-user"
      fi
      # 如果当前架构不是 s390x，则添加 s390x-linux-user 目标
      if [ "$arch" != "s390x" ]; then
        QEMU_TARGETS="$QEMU_TARGETS s390x-linux-user"
      fi
      # 如果当前架构不是 386，则添加 i386-linux-user 目标
      if [ "$arch" != "386" ] ; then
        QEMU_TARGETS="$QEMU_TARGETS i386-linux-user"
      fi
      # 如果当前架构不是 mips64le，则添加 mips64el-linux-user 目标
      if [ "$arch" != "mips64le" ] ; then
        QEMU_TARGETS="$QEMU_TARGETS mips64el-linux-user"
      fi
      # 如果当前架构不是 mips64，则添加 mips64-linux-user 目标
      if [ "$arch" != "mips64" ] ; then
        QEMU_TARGETS="$QEMU_TARGETS mips64-linux-user"
      fi
      # 如果当前架构不是 loong64，则添加 loongarch64-linux-user 目标
      if [ "$arch" != "loong64" ] ; then
        QEMU_TARGETS="$QEMU_TARGETS loongarch64-linux-user"
      fi
      ;;
  esac
fi

# 设置调试模式，执行命令前打印命令
set -x

# 运行 QEMU 配置脚本
# ./configure 是 QEMU 的配置脚本
# 各参数说明如下：

# --prefix=/usr 指定安装路径前缀为 /usr
./configure \
  --prefix=/usr \
  
  # --with-pkgversion=$QEMU_VERSION 指定 QEMU 的版本号
  --with-pkgversion=$QEMU_VERSION \
  
  # --enable-linux-user 启用 Linux 用户模式模拟
  # 这是用于在主机上运行其他架构的 Linux 二进制文件
  --enable-linux-user \
  
  # --disable-system 禁用系统模式模拟
  # 系统模式用于模拟完整的计算机系统，这里不需要
  --disable-system \
  
  # --static 生成静态链接的可执行文件
  # 静态链接可以避免依赖动态库，适合容器化部署
  --static \
  
  # --disable-brlapi 禁用 Braille 终端支持
  --disable-brlapi \
  
  # --disable-cap-ng 禁用 Linux capabilities 支持
  --disable-cap-ng \
  
  # --disable-capstone 禁用 Capstone 反汇编引擎
  --disable-capstone \
  
  # --disable-curl 禁用 curl 网络库支持
  --disable-curl \
  
  # --disable-curses 禁用 curses 终端界面支持
  --disable-curses \
  
  # --disable-docs 禁用文档生成
  --disable-docs \
  
  # --disable-gcrypt 禁用 libgcrypt 加密库
  --disable-gcrypt \
  
  # --disable-gnutls 禁用 GnuTLS TLS/SSL 库
  --disable-gnutls \
  
  # --disable-gtk 禁用 GTK 图形界面支持
  --disable-gtk \
  
  # --disable-guest-agent 禁用 QEMU Guest Agent
  --disable-guest-agent \
  
  # --disable-guest-agent-msi 禁用 QEMU Guest Agent MSI 安装包
  --disable-guest-agent-msi \
  
  # --disable-libiscsi 禁用 iSCSI 库支持
  --disable-libiscsi \
  
  # --disable-libnfs 禁用 NFS 客户端库
  --disable-libnfs \
  
  # --disable-mpath 禁用多路径设备支持
  --disable-mpath \
  
  # --disable-nettle 禁用 Nettle 加密库
  --disable-nettle \
  
  # --disable-opengl 禁用 OpenGL 图形支持
  --disable-opengl \
  
  # --disable-sdl 禁用 SDL 图形库支持
  --disable-sdl \
  
  # --disable-spice 禁用 SPICE 远程显示协议
  --disable-spice \
  
  # --disable-tools 禁用 QEMU 工具集
  --disable-tools \
  
  # --disable-vte 禁用 VTE 终端模拟器
  --disable-vte \
  
  # --disable-werror 禁止将警告视为错误
  --disable-werror \
  
  # --disable-debug-info 禁用调试信息生成
  --disable-debug-info \
  
  # --disable-glusterfs 禁用 GlusterFS 文件系统支持
  --disable-glusterfs \
  
  # --cross-prefix=$(xx-info)- 指定交叉编译工具链前缀
  # xx-info 输出交叉编译目标信息
  --cross-prefix=$(xx-info)- \
  
  # --host-cc 指定主机编译器
  # TARGETPLATFORM= TARGETPAIR= xx-clang --print-target-triple 获取目标三元组
  # -clang 表示使用 Clang 编译器
  --host-cc=$(TARGETPLATFORM= TARGETPAIR= xx-clang --print-target-triple)-clang \
  
  # --cc 指定目标编译器
  --cc=$(xx-clang --print-target-triple)-clang \
  
  # --extra-ldflags=-latomic 添加额外的链接器标志
  # -latomic 链接原子操作库
  --extra-ldflags=-latomic \
  
  # --target-list="$QEMU_TARGETS" 指定要编译的目标架构列表
  --target-list="$QEMU_TARGETS"
