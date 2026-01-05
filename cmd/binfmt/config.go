// 构建约束：此文件仅在非 Windows 平台上编译
//go:build !windows
// +build !windows

package main

import (
	"log"
	"os"

	"github.com/containerd/platforms"
	"github.com/moby/buildkit/util/archutil"
)

// QEMU binfmt 配置参考
// 参考文档：https://github.com/qemu/qemu/blob/master/scripts/qemu-binfmt-conf.sh
// binfmt (Binary Format) 是 Linux 内核的一个功能，允许内核识别和执行不同架构的二进制文件
// 通过配置 binfmt，可以在 x86_64 系统上运行 ARM、RISC-V 等其他架构的程序

// config 结构体：定义 binfmt 的配置信息
type config struct {
	binary string // QEMU 模拟器二进制文件名称（如 qemu-aarch64）
	magic  string // ELF 文件的魔数（magic number），用于识别二进制文件类型
	mask   string // 魔数掩码，用于匹配魔数的特定部分
}

// configs 映射：存储所有支持的架构及其对应的 binfmt 配置
// 键：架构名称（如 "amd64"、"arm64"）
// 值：该架构的配置信息
var configs = map[string]config{
	// AMD64 架构配置（x86_64）
	"amd64": {
		binary: "qemu-x86_64",                                                                      // QEMU x86_64 模拟器
		magic:  `\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00`,          // 64位 ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
	// ARM64 架构配置（AArch64）
	"arm64": {
		binary: "qemu-aarch64",                                                                     // QEMU AArch64 模拟器
		magic:  `\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00`,          // 64位 ARM ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
	// ARM 架构配置（32位）
	"arm": {
		binary: "qemu-arm",                                                                         // QEMU ARM 模拟器
		magic:  `\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00`,          // 32位 ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
	// s390x 架构配置（IBM Z 大型机）
	"s390x": {
		binary: "qemu-s390x",                                                                       // QEMU s390x 模拟器
		magic:  `\x7fELF\x02\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x16`,          // s390x ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff`, // 魔数掩码
	},
	// ppc64le 架构配置（PowerPC 64位 Little Endian）
	"ppc64le": {
		binary: "qemu-ppc64le",                                                                     // QEMU PowerPC64LE 模拟器
		magic:  `\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x15\x00`,          // PowerPC64LE ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\x00`, // 魔数掩码
	},
	// riscv64 架构配置（RISC-V 64位）
	"riscv64": {
		binary: "qemu-riscv64",                                                                     // QEMU RISC-V64 模拟器
		magic:  `\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xf3\x00`,          // RISC-V64 ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
	// 386 架构配置（x86 32位）
	"386": {
		binary: "qemu-i386",                                                                        // QEMU i386 模拟器
		magic:  `\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00`,          // 32位 ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
	// mips64le 架构配置（MIPS 64位 Little Endian）
	"mips64le": {
		binary: "qemu-mips64el",                                                                    // QEMU MIPS64EL 模拟器
		magic:  `\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x08\x00`,          // MIPS64LE ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\x00\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
	// mips64 架构配置（MIPS 64位 Big Endian）
	"mips64": {
		binary: "qemu-mips64",                                                                      // QEMU MIPS64 模拟器
		magic:  `\x7fELF\x02\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x08`,          // MIPS64 ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff`, // 魔数掩码
	},
	// loong64 架构配置（LoongArch 64位）
	"loong64": {
		binary: "qemu-loongarch64",                                                                 // QEMU LoongArch64 模拟器
		magic:  `\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x01`,          // LoongArch64 ELF 文件魔数
		mask:   `\xff\xff\xff\xff\xff\xff\xff\xfc\x00\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff`, // 魔数掩码
	},
}

// allArch 函数：获取所有需要配置的架构列表
// 返回值：架构名称的切片
//
// 此函数的工作原理：
// 1. 首先获取当前系统支持的平台列表
// 2. 解析每个平台，提取架构名称
// 3. 对于 configs 中定义但不在当前支持列表中的架构：
//   - 检查对应的 QEMU 二进制文件是否存在
//   - 如果存在，则将该架构添加到返回列表中
//   - 如果不存在，也添加到列表中（让 install() 函数打印错误信息）
//
// 这样做的目的是确保所有已安装的 QEMU 模拟器都能正确配置 binfmt
func allArch() []string {
	// 创建一个空的映射，用于存储当前支持的架构
	m := map[string]struct{}{}

	// 遍历所有支持的平台
	for _, pp := range formatPlatforms(archutil.SupportedPlatforms(true)) {
		// 解析平台字符串
		p, err := platforms.Parse(pp)
		if err == nil {
			// 如果解析成功，将架构名称添加到映射中
			m[p.Architecture] = struct{}{}
		} else {
			// 如果解析失败，记录错误日志
			log.Printf("error: %+v", err)
		}
	}

	// 创建输出切片，预分配容量以提高性能
	out := make([]string, 0, len(configs))

	// 遍历所有配置的架构
	for name := range configs {
		// 如果该架构不在当前支持的平台列表中
		if _, ok := m[name]; !ok {
			// 尝试获取该架构的二进制文件路径
			if _, fullPath, err := getBinaryNames(configs[name]); err == nil {
				// 检查二进制文件是否存在
				if _, err := os.Stat(fullPath); err == nil {
					// 如果存在，将该架构添加到输出列表
					out = append(out, name)
				}
			} else {
				// 如果获取路径失败，也添加到列表中
				// 这样 install() 函数会打印错误信息，帮助用户诊断问题
				out = append(out, name)
			}
		}
	}

	// 返回需要配置的架构列表
	return out
}
