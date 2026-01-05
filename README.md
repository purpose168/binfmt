# Binfmt

[![GitHub release](https://img.shields.io/github/release/tonistiigi/binfmt.svg?style=flat-square)](https://github.com/tonistiigi/binfmt/releases/latest)
[![CI Status](https://img.shields.io/github/actions/workflow/status/tonistiigi/binfmt/ci.yml?label=ci&logo=github&style=flat-square)](https://github.com/tonistiigi/binfmt/actions?query=workflow%3Aci)
[![Go Report Card](https://goreportcard.com/badge/github.com/tonistiigi/binfmt?style=flat-square)](https://goreportcard.com/report/github.com/tonistiigi/binfmt)
[![Docker Pulls](https://img.shields.io/docker/pulls/tonistiigi/binfmt.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/tonistiigi/binfmt/)

跨平台模拟器集合，通过 Docker 镜像分发。

## 构建本地二进制文件

```bash
docker buildx bake
```

此命令将为您的本地平台构建 qemu-user 模拟器二进制文件到 `bin` 目录。

## 构建测试镜像

```bash
REPO=myuser/binfmt docker buildx bake --load mainline
docker run --privileged --rm myuser/binfmt
```

输出类似于：

```
{
  "supported": [
    "linux/amd64",
    "linux/arm64",
    "linux/riscv64",
    "linux/ppc64le",
    "linux/s390x",
    "linux/386",
    "linux/arm/v7",
    "linux/arm/v6"
  ],
  "emulators": [
    "qemu-aarch64",
    "qemu-arm",
    "qemu-i386",
    "qemu-ppc64le",
    "qemu-riscv64",
    "qemu-s390x"
  ]
}
```

## 安装模拟器

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
docker run --privileged --rm tonistiigi/binfmt --install arm64,riscv64,arm
```

## 从 Docker-Compose 安装模拟器

```docker
version: "3"
services:
  emulator:
    image: tonistiigi/binfmt
    container_name: emulator
    privileged: true
    command: --install all
    network_mode: bridge
    restart: "no"
```
仅使用容器的 `restart-policy` 为 `no`，否则 Docker 将持续重启容器。

## 卸载模拟器

```bash
docker run --privileged --rm tonistiigi/binfmt --uninstall qemu-aarch64
```

模拟器名称可以从状态输出中找到。

您也可以卸载特定模拟器的所有架构：

```bash
docker run --privileged --rm tonistiigi/binfmt --uninstall qemu-*
```

## 显示版本

```bash
docker run --privileged --rm tonistiigi/binfmt --version
```
```
binfmt/9a44d27 qemu/v6.0.0 go/1.15.11
```

## 开发命令

```bash
# 验证代码格式检查器 (validate linter)
./hack/lint

# 验证供应商文件 (validate vendored files)
./hack/validate-vendor

# 更新供应商文件 (update vendored files)
./hack/update-vendor

# 测试，仅在允许在内核中安装模拟器的节点上运行 (test, only run on nodes where you allow emulators to be installed in kernel)
./hack/install-and-test
```

## 测试当前模拟支持

```
docker run --rm --platform linux/arm64 alpine uname -a
docker run --rm --platform linux/arm/v7 alpine uname -a
docker run --rm --platform linux/ppc64le alpine uname -a
docker run --rm --platform linux/s390x alpine uname -a
docker run --rm --platform linux/riscv64 alpine uname -a
```

## `buildkit` 目标

此仓库还为 BuildKit 的自动模拟支持提供帮助器 https://github.com/moby/buildkit/pull/1528。
这些二进制文件是 BuildKit 专用的，不应使用 `binfmt_misc` 安装到内核中。

## 许可证

MIT。详见 `LICENSE` 获取更多详细信息。
关于 QEMU，请参见 https://wiki.qemu.org/License
