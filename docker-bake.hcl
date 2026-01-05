// 定义变量：仓库标识符
// REPO_SLUG 用于指定 Docker 镜像的仓库路径，格式为 "用户名/仓库名"
variable "REPO_SLUG" {
  default = "tonistiigi/binfmt"
}

// 定义变量：QEMU 源代码仓库地址
// QEMU_REPO 指定 QEMU 的 Git 仓库 URL
variable "QEMU_REPO" {
  default = "https://github.com/qemu/qemu"
}

// 定义变量：QEMU 版本号
// QEMU_VERSION 指定要使用的 QEMU 版本标签
variable "QEMU_VERSION" {
  default = "v10.0.4"
}

// 定义变量：QEMU 补丁列表
// QEMU_PATCHES 指定要应用的 QEMU 补丁名称，多个补丁用逗号分隔
variable "QEMU_PATCHES" {
  default = "cpu-max-arm"
}

// 特殊目标：元数据辅助目标
// 用于与 docker/metadata-action 集成，生成镜像标签
// 参考文档：https://github.com/docker/metadata-action#bake-definition
target "meta-helper" {
  tags = ["${REPO_SLUG}:test"]
}

// 通用配置目标
// 定义所有目标共享的通用参数
target "_common" {
  args = {
    // 保留 Git 目录：在构建上下文中保留 .git 目录
    // 这使得构建过程可以访问 Git 历史和版本信息
    BUILDKIT_CONTEXT_KEEP_GIT_DIR = 1
  }
}

// 默认组：定义默认构建目标
// 当运行 docker buildx bake 时，如果不指定目标，将构建此组中的目标
group "default" {
  targets = ["binaries"]
}

// 全架构目标：定义支持的所有平台
// 用于构建多架构镜像
target "all-arch" {
  platforms = [
    "linux/amd64",      // AMD64 架构（x86_64）
    "linux/arm64",      // ARM64 架构（aarch64）
    "linux/arm/v6",     // ARM v6 架构
    "linux/arm/v7",     // ARM v7 架构
    "linux/ppc64le",    // PowerPC 64位 Little Endian
    "linux/s390x",      // IBM Z 架构
    "linux/riscv64",    // RISC-V 64位架构
    "linux/386",        // x86 32位架构
  ]
}

// 二进制文件目标：构建本地平台的二进制文件
// 输出到 ./bin 目录
target "binaries" {
  // 继承通用配置
  inherits = ["_common"]
  // 输出目录：将构建的二进制文件输出到本地 ./bin 目录
  output = ["./bin"]
  // 平台：仅构建本地平台
  platforms = ["local"]
  // Dockerfile 目标：构建 binaries 阶段
  target = "binaries"
}

// 全架构二进制文件目标：构建所有架构的二进制文件
target "binaries-all" {
  // 继承 binaries 和 all-arch 配置
  inherits = ["binaries", "all-arch"]
}

// 主线版本目标：构建标准的 binfmt 镜像
// 这是默认的生产版本
target "mainline" {
  // 继承元数据辅助和通用配置
  inherits = ["meta-helper", "_common"]
  // 构建参数
  args = {
    QEMU_REPO = QEMU_REPO
    QEMU_VERSION = QEMU_VERSION
    QEMU_PATCHES = QEMU_PATCHES
    // 保留 argv0：保持程序名称，用于进程识别
    QEMU_PRESERVE_ARGV0 = "1"
  }
  // 缓存配置：内联缓存（嵌入到镜像中）
  cache-to = ["type=inline"]
  // 从 master 分支的镜像加载缓存
  cache-from = ["${REPO_SLUG}:master"]
}

// 主线版本全架构目标：构建所有架构的主线镜像
target "mainline-all" {
  // 继承 mainline 和 all-arch 配置
  inherits = ["mainline", "all-arch"]
}

// Buildkit 专用版本目标：为 Docker Buildkit 优化的版本
// Buildkit 是 Docker 的下一代构建工具
target "buildkit" {
  // 继承 mainline 配置
  inherits = ["mainline"]
  // 构建参数
  args = {
    // 二进制文件前缀：为 Buildkit 添加前缀
    BINARY_PREFIX = "buildkit-"
    // 额外的 Buildkit 补丁：直接执行优化
    QEMU_PATCHES = "${QEMU_PATCHES},buildkit-direct-execve-v10.0"
    // 不保留 argv0：Buildkit 不需要此功能
    QEMU_PRESERVE_ARGV0 = ""
  }
  // 从 buildkit-master 分支的镜像加载缓存
  cache-from = ["${REPO_SLUG}:buildkit-master"]
  // 仅构建 binaries 阶段
  target = "binaries"
}

// Buildkit 全架构目标：构建所有架构的 Buildkit 镜像
target "buildkit-all" {
  // 继承 buildkit 和 all-arch 配置
  inherits = ["buildkit", "all-arch"]
}

// Buildkit 测试目标：用于测试 Buildkit 集成
target "buildkit-test" {
  // 继承 buildkit 配置
  inherits = ["buildkit"]
  // 构建 buildkit-test 阶段
  target = "buildkit-test"
  // 不保存缓存
  cache-to = []
  // 不设置标签
  tags = []
}

// 桌面环境版本目标：为桌面环境优化的版本
// 包含额外的补丁以支持桌面应用
target "desktop" {
  // 继承 mainline 配置
  inherits = ["mainline"]
  // 构建参数
  args = {
    // 添加 pretcode 补丁：用于桌面环境的特殊处理
    QEMU_PATCHES = "${QEMU_PATCHES},pretcode"
  }
  // 从 desktop-master 分支的镜像加载缓存
  cache-from = ["${REPO_SLUG}:desktop-master"]
}

// 桌面环境全架构目标：构建所有架构的桌面环境镜像
target "desktop-all" {
  // 继承 desktop 和 all-arch 配置
  inherits = ["desktop", "all-arch"]
}

// 构建归档目标：创建 QEMU 二进制文件的归档
target "build-archive" {
  // 继承 mainline 配置
  inherits = ["mainline"]
  // 构建 build-archive 阶段
  target = "build-archive"
  // 输出到 ./bin 目录
  output = ["./bin"]
}

// 构建归档全架构目标：创建所有架构的构建归档
target "build-archive-all" {
  // 继承 build-archive 和 all-arch 配置
  inherits = ["build-archive", "all-arch"]
}

// Binfmt 归档目标：创建 binfmt 配置和二进制文件的归档
target "binfmt-archive" {
  // 继承 mainline 配置
  inherits = ["mainline"]
  // 构建 binfmt-archive 阶段
  target = "binfmt-archive"
  // 输出到 ./bin 目录
  output = ["./bin"]
}

// Binfmt 归档全架构目标：创建所有架构的 binfmt 归档
target "binfmt-archive-all" {
  // 继承 binfmt-archive 和 all-arch 配置
  inherits = ["binfmt-archive", "all-arch"]
}

// 完整归档目标：创建包含所有内容的完整归档
target "archive" {
  // 继承 mainline 配置
  inherits = ["mainline"]
  // 构建 archive 阶段
  target = "archive"
  // 输出到 ./bin 目录
  output = ["./bin"]
}

// 完整归档全架构目标：创建所有架构的完整归档
target "archive-all" {
  // 继承 archive 和 all-arch 配置
  inherits = ["archive", "all-arch"]
}
