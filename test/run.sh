#!/usr/bin/env sh
# 使用系统默认的 sh shell 执行此脚本
# /usr/bin/env sh 会查找 PATH 中的 sh 解释器

# 创建符号链接
# ln -s 创建软链接（符号链接）
# /usr/bin/env 是源文件
# /work/env 是链接目标
# 这可能是为了在测试环境中提供 env 命令的访问路径
ln -s /usr/bin/env /work/env

# 编译 Go 程序：printargs
# go build 编译 Go 源代码
# print/printargs.go 是源文件路径
# printargs 是一个打印程序参数的工具
go build print/printargs.go

# 编译 Go 程序：execargv0
# exec/execargv0.go 是源文件路径
# execargv0 是一个执行程序并显示 argv[0] 的工具
go build exec/execargv0.go

# 编译 Go 程序：chwd
# change-workdir/chwd.go 是源文件路径
# chwd 是一个改变工作目录的工具
go build change-workdir/chwd.go

# 输出当前测试的架构信息
# uname -m 显示机器硬件名称（如 x86_64、aarch64 等）
# $(uname -m) 是命令替换，执行 uname -m 并返回结果
echo "testing $(uname -m)"

# 运行 Bats 测试套件
# ./test.bats 是 Bats（Bash Automated Testing System）测试文件
# Bats 是一个用于测试 shell 脚本的测试框架
./test.bats

# 设置交叉编译的目标架构为 arm64
# crossArch 是一个变量，存储目标架构名称
# arm64 是 64 位 ARM 架构
crossArch=arm64

# 设置对应的模拟器名称
# crossEmulator 是一个变量，存储 QEMU 模拟器的名称
# aarch64 是 ARM 64 位架构的 QEMU 模拟器名称
crossEmulator=aarch64

# 检查当前系统架构
# [ "$(uname -m)" = "aarch64" ] 判断当前是否为 ARM 64 位架构
# 如果是，则切换交叉编译目标为 amd64
if [ "$(uname -m)" = "aarch64" ]; then
  # 将交叉编译目标架构设置为 amd64
  # amd64 是 64 位 x86 架构
  crossArch="amd64"
  # 将模拟器名称设置为 x86_64
  # x86_64 是 64 位 x86 架构的 QEMU 模拟器名称
  crossEmulator="x86_64"
fi

# 创建符号链接到交叉架构的 env
# ln -sf 创建符号链接，如果目标已存在则强制覆盖
# /crossarch/usr/bin/env 是交叉架构环境中的 env 命令
# /work/env 是链接目标
# 这可能是为了在测试环境中使用交叉架构的 env 命令
ln -sf /crossarch/usr/bin/env /work/env

# 为交叉架构编译 printargs
# GOARCH=$crossArch 设置 Go 编译的目标架构
# $crossArch 是之前设置的交叉编译目标架构变量
# 这会编译指定架构的可执行文件
GOARCH=$crossArch go build print/printargs.go

# 为交叉架构编译 execargv0
# 同样使用交叉编译目标架构
GOARCH=$crossArch go build exec/execargv0.go

# 为交叉架构编译 chwd
# 同样使用交叉编译目标架构
GOARCH=$crossArch go build change-workdir/chwd.go

# 测试交叉架构程序是否可以直接运行
# ./printargs 尝试运行交叉编译的 printargs 程序
# >/dev/null 将标准输出重定向到 /dev/null（丢弃输出）
# 2>/dev/nulll 将标准错误输出重定向到 /dev/nulll（注意这里有个拼写错误，应该是 /dev/null）
# 如果程序能成功运行（退出码为 0），说明模拟器已安装
if ./printargs >/dev/null 2>/dev/nulll; then
  # 输出错误信息
  # 说明无法测试模拟器，因为模拟器已经安装在内核中
  # $crossEmulator 是模拟器名称变量
  echo "can't test emulator because $crossEmulator emulator is installed in the kernel"
  # 退出脚本，返回错误码 1
  exit 1
fi

# 输出正在测试的架构信息
# $crossEmulator 是要测试的模拟器架构
echo "testing $crossEmulator"

# 运行 Bats 测试套件，使用指定的模拟器
# BINFMT_EMULATOR=$crossEmulator 设置环境变量，指定要使用的模拟器
# 这个环境变量会被测试脚本使用
# ./test.bats 运行 Bats 测试文件
BINFMT_EMULATOR=$crossEmulator ./test.bats
