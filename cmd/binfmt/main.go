// binfmt - QEMU binfmt_misc 管理工具
//
// 本程序用于在 Linux 系统上安装、卸载和管理 QEMU binfmt_misc 配置
// binfmt_misc 是 Linux 内核的一个功能，允许系统识别和执行不同架构的二进制文件
// 通过配置 binfmt_misc，可以在一个架构的机器上运行其他架构的程序（如 x86_64 上运行 ARM64 程序）
//
// 主要功能：
// - 安装指定架构的 QEMU 模拟器配置
// - 卸载已安装的架构配置
// - 查看当前系统支持的架构和已安装的模拟器
// - 自动挂载 binfmt_misc 文件系统
//
// 使用场景：
// - 跨平台开发和测试
// - Docker 多架构镜像构建
// - CI/CD 环境中的多架构测试
// - 在一个主机上运行多个架构的容器
package main

import (
	"encoding/json" // JSON 编解码库
	"flag"          // 命令行参数解析库
	"fmt"           // 格式化输出库
	"log"           // 日志输出库
	"os"            // 操作系统接口库
	"path/filepath" // 文件路径操作库
	"runtime"       // 运行时信息库
	"strings"       // 字符串操作库
	"syscall"       // 系统调用库

	"github.com/containerd/platforms"                           // containerd 平台解析库
	"github.com/moby/buildkit/util/archutil"                    // BuildKit 架构工具库
	ocispecs "github.com/opencontainers/image-spec/specs-go/v1" // OCI 镜像规范
	"github.com/pkg/errors"                                     // 错误处理增强库
)

var (
	// mount 定义 binfmt_misc 文件系统的挂载点
	// 默认为 "/proc/sys/fs/binfmt_misc"，这是 Linux 内核中 binfmt_misc 的标准挂载位置
	mount string

	// toInstall 指定需要安装的架构列表
	// 可以是单个架构（如 "arm64"）或多个架构（如 "arm64,arm,amd64"）
	// 特殊值 "all" 表示安装所有支持的架构
	toInstall string

	// toUninstall 指定需要卸载的架构列表
	// 可以是架构名称或 QEMU 模拟器名称（如 "qemu-aarch64"）
	toUninstall string

	// flVersion 是否显示版本信息
	// 为 true 时打印程序版本、QEMU 版本和 Go 版本
	flVersion bool
)

// init 函数在程序启动时自动执行
// 用于初始化命令行参数和配置
func init() {
	// 定义命令行参数
	// -mount: 指定 binfmt_misc 的挂载点，默认为 /proc/sys/fs/binfmt_misc
	flag.StringVar(&mount, "mount", "/proc/sys/fs/binfmt_misc", "binfmt_misc mount point")

	// -install: 指定要安装的架构，多个架构用逗号分隔
	// 示例: -install arm64,amd64 或 -install all
	flag.StringVar(&toInstall, "install", "", "architectures to install")

	// -uninstall: 指定要卸载的架构，多个架构用逗号分隔
	// 示例: -uninstall arm64 或 -uninstall qemu-aarch64
	flag.StringVar(&toUninstall, "uninstall", "", "architectures to uninstall")

	// -version: 显示版本信息
	flag.BoolVar(&flVersion, "version", false, "display version")

	// 完全禁用 archutil.SupportedPlatforms 的缓存
	// CacheMaxAge = 0 表示每次都重新查询支持的平台
	// 这样可以确保获取最新的平台支持信息，避免缓存过期导致的问题
	archutil.CacheMaxAge = 0
}

// uninstall 卸载指定架构的 binfmt 配置
//
// 参数:
//
//	arch: 要卸载的架构名称（如 "arm64"）或 QEMU 模拟器名称（如 "qemu-aarch64"）
//
// 返回值:
//
//	error: 如果卸载失败返回错误，成功返回 nil
//
// 工作原理:
// 1. 读取 binfmt_misc 挂载点目录中的所有文件
// 2. 跳过系统保留文件（register、status、WSLInterop）
// 3. 查找与指定架构匹配的配置文件
// 4. 向匹配的配置文件写入 "-1" 来禁用该配置
//
// 注意:
// - 卸载操作是立即生效的，不需要重启
// - 卸载后，该架构的二进制文件将无法直接运行
// - 如果找不到匹配的配置，返回 "not found" 错误
func uninstall(arch string) error {
	// 读取 binfmt_misc 挂载点目录中的所有文件
	// 每个文件代表一个已注册的 binfmt 配置
	fis, err := os.ReadDir(mount)
	if err != nil {
		return err
	}

	// 遍历目录中的所有文件
	for _, fi := range fis {
		// 跳过系统保留文件
		// register: 用于注册新的 binfmt 配置
		// status: binfmt_misc 文件系统的状态文件
		// WSLInterop: Windows Subsystem for Linux 的互操作配置
		if fi.Name() == "register" || fi.Name() == "status" || fi.Name() == "WSLInterop" {
			continue
		}

		// 检查文件名是否匹配要卸载的架构
		// 支持两种匹配方式：
		// 1. 完全匹配（如 "arm64"）
		// 2. 后缀匹配（如 "qemu-aarch64" 或 "aarch64"）
		if fi.Name() == arch || strings.HasSuffix(fi.Name(), "-"+arch) {
			// 向配置文件写入 "-1" 来禁用该配置
			// 这是 binfmt_misc 的标准卸载方式
			// 文件权限设置为 0600（仅所有者可读写）
			return os.WriteFile(filepath.Join(mount, fi.Name()), []byte("-1"), 0600)
		}
	}

	// 如果没有找到匹配的配置，返回错误
	return errors.Errorf("not found")
}

// getBinaryNames 获取 QEMU 模拟器二进制文件的名称和完整路径
//
// 参数:
//
//	cfg: 架构配置信息（包含 binary、magic、mask 等字段）
//
// 返回值:
//
//	string: 二进制文件的基本名称（如 "qemu-aarch64"）
//	string: 二进制文件的完整路径（如 "/usr/bin/qemu-aarch64"）
//	error: 如果路径配置错误返回错误
//
// 工作原理:
// 1. 从环境变量 QEMU_BINARY_PATH 获取二进制文件目录，默认为 /usr/bin
// 2. 从配置中获取二进制文件基本名称（如 "qemu-aarch64"）
// 3. 检查环境变量 QEMU_BINARY_PREFIX，如果存在则添加前缀
// 4. 拼接目录和文件名得到完整路径
//
// 环境变量:
//
//	QEMU_BINARY_PATH: 指定 QEMU 二进制文件的目录路径
//	QEMU_BINARY_PREFIX: 指定 QEMU 二进制文件的前缀（不能包含路径分隔符）
//
// 注意:
// - QEMU_BINARY_PREFIX 不能包含路径分隔符，否则返回错误
// - 这允许用户自定义 QEMU 二进制文件的位置和命名
func getBinaryNames(cfg config) (string, string, error) {
	// 获取 QEMU 二进制文件目录
	// 默认为 /usr/bin，可通过环境变量 QEMU_BINARY_PATH 覆盖
	binaryPath := "/usr/bin"
	if v := os.Getenv("QEMU_BINARY_PATH"); v != "" {
		binaryPath = v
	}

	// 获取二进制文件的基本名称
	// 从配置中读取，如 "qemu-aarch64"
	binaryBasename := cfg.binary

	// 检查是否需要添加前缀
	// 环境变量 QEMU_BINARY_PREFIX 可以用于自定义二进制文件名
	// 例如设置为 "custom-"，则最终名称为 "custom-qemu-aarch64"
	if binaryPrefix := os.Getenv("QEMU_BINARY_PREFIX"); binaryPrefix != "" {
		// 检查前缀是否包含路径分隔符
		// 路径分隔符会导致安全问题，因此禁止使用
		if strings.ContainsRune(binaryPrefix, os.PathSeparator) {
			return "", "", errors.New("binary prefix must not contain path separator (Hint: set $QEMU_BINARY_PATH to specify the directory)")
		}
		binaryBasename = binaryPrefix + binaryBasename
	}

	// 拼接完整路径
	// 使用 filepath.Join 确保路径格式正确（处理不同操作系统的路径分隔符）
	binaryFullpath := filepath.Join(binaryPath, binaryBasename)

	return binaryBasename, binaryFullpath, nil
}

// install 安装指定架构的 binfmt 配置
//
// 参数:
//
//	arch: 要安装的架构名称（如 "arm64"）
//
// 返回值:
//
//	error: 如果安装失败返回错误，成功返回 nil
//
// 工作原理:
// 1. 检查架构是否支持
// 2. 打开 binfmt_misc 的 register 文件
// 3. 构建注册字符串（包含二进制路径、魔数、掩码、标志等）
// 4. 将注册字符串写入 register 文件
//
// 注册字符串格式:
//
//	:name:M:offset:magic:mask:interpreter:flags
//	- name: 模拟器名称（如 "qemu-aarch64"）
//	- M: 表示使用魔数匹配
//	- offset: 魔数偏移量（本程序固定为 0）
//	- magic: ELF 文件的魔数
//	- mask: 魔数掩码
//	- interpreter: QEMU 模拟器的完整路径
//	- flags: 标志位（C=清除，F=固定，P=保留 argv0）
//
// 错误处理:
// - 如果 binfmt_misc 未挂载，返回 ENOENT 错误
// - 如果权限不足，返回 EPERM 错误
// - 如果配置已存在，返回 EEXIST 错误
func install(arch string) error {
	// 检查架构是否支持
	// 从 configs 映射中查找对应的配置
	cfg, ok := configs[arch]
	if !ok {
		return errors.Errorf("unsupported architecture: %v", arch)
	}

	// 构造 register 文件的完整路径
	// register 文件用于注册新的 binfmt 配置
	register := filepath.Join(mount, "register")

	// 以只写模式打开 register 文件
	// 不需要创建文件，因为 register 文件已经存在
	file, err := os.OpenFile(register, os.O_WRONLY, 0)
	if err != nil {
		var pathErr *os.PathError
		ok := errors.As(err, &pathErr)

		// 检查是否是文件不存在错误
		// 这通常意味着 binfmt_misc 文件系统未挂载
		if ok && errors.Is(pathErr.Err, syscall.ENOENT) {
			return errors.Errorf("ENOENT opening %s is it mounted?", register)
		}

		// 检查是否是权限错误
		// 这通常意味着当前用户没有写权限
		if ok && errors.Is(pathErr.Err, syscall.EPERM) {
			return errors.Errorf("EPERM opening %s check permissions?", register)
		}

		// 其他错误
		return errors.Errorf("Cannot open %s: %s", register, err)
	}
	defer file.Close()

	// 设置标志位
	// C: 清除标志，表示在注册前清除现有配置
	// F: 固定标志，表示配置不能被覆盖
	flags := "CF"

	// 检查是否需要保留 argv0
	// 环境变量 QEMU_PRESERVE_ARGV0 设置为非空值时启用
	// P: 保留 argv0 标志，保持程序名称不变
	// 这对于某些依赖程序名称的应用很重要
	if v := os.Getenv("QEMU_PRESERVE_ARGV0"); v != "" {
		flags += "P"
	}

	// 获取 QEMU 二进制文件的名称和路径
	binaryBasename, binaryFullpath, err := getBinaryNames(cfg)
	if err != nil {
		return err
	}

	// 构建注册字符串
	// 格式: :name:M:offset:magic:mask:interpreter:flags
	// 示例: :qemu-aarch64:M:0:\x7fELF...\xff\xff...:/usr/bin/qemu-aarch64:CFP
	line := fmt.Sprintf(":%s:M:0:%s:%s:%s:%s", binaryBasename, cfg.magic, cfg.mask, binaryFullpath, flags)

	// 将注册字符串写入 register 文件
	// sysfs 不支持部分写入，写入失败时无法恢复
	_, err = file.Write([]byte(line))
	if err != nil {
		var pathErr *os.PathError

		// 检查是否是已存在错误
		// 这意味着该配置已经被注册过了
		if errors.As(err, &pathErr) && errors.Is(pathErr.Err, syscall.EEXIST) {
			return errors.Errorf("%s already registered", binaryBasename)
		}

		// 其他错误
		return errors.Errorf("cannot register %q to %s: %s", binaryFullpath, register, err)
	}

	return nil
}

// printStatus 打印当前系统的 binfmt 配置状态
//
// 返回值:
//
//	error: 如果读取状态失败返回错误，成功返回 nil
//
// 输出格式:
//
//	JSON 格式，包含两个字段：
//	- supported: 系统支持的架构列表
//	- emulators: 已安装的模拟器列表
//
// 工作原理:
// 1. 读取 binfmt_misc 挂载点目录中的所有文件
// 2. 跳过系统保留文件
// 3. 读取每个配置文件的内容
// 4. 检查配置是否启用（以 "enabled" 开头）
// 5. 收集所有启用的模拟器名称
// 6. 获取系统支持的架构列表
// 7. 以 JSON 格式输出结果
//
// 注意:
// - 输出为 JSON 格式，便于程序解析
// - 只有状态为 "enabled" 的配置才会被包含在输出中
func printStatus() error {
	// 读取 binfmt_misc 挂载点目录中的所有文件
	fis, err := os.ReadDir(mount)
	if err != nil {
		return err
	}

	// 收集已启用的模拟器
	var emulators []string
	for _, f := range fis {
		// 跳过系统保留文件
		if f.Name() == "register" || f.Name() == "status" {
			continue
		}

		// 读取配置文件的内容
		// 内容通常为 "enabled" 或 "disabled"
		dt, err := os.ReadFile(filepath.Join(mount, f.Name()))
		if err != nil {
			return err
		}

		// 检查配置是否启用
		if strings.HasPrefix(string(dt), "enabled") {
			emulators = append(emulators, f.Name())
		}
	}

	// 构建输出结构
	// 使用匿名结构体定义 JSON 输出格式
	out := struct {
		Supported []string `json:"supported"` // 系统支持的架构列表
		Emulators []string `json:"emulators"` // 已安装的模拟器列表
	}{
		Supported: formatPlatforms(archutil.SupportedPlatforms(true)),
		Emulators: emulators,
	}

	// 将结构体序列化为 JSON
	// 使用缩进格式化，便于人类阅读
	dt, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return err
	}

	// 输出 JSON
	fmt.Printf("%s\n", dt)
	return nil
}

// formatPlatforms 格式化平台信息列表
//
// 参数:
//
//	p: OCI 平台规格列表
//
// 返回值:
//
//	[]string: 格式化后的平台字符串列表
//
// 工作原理:
// 1. 遍历平台列表
// 2. 对每个平台进行规范化处理
// 3. 使用 platforms.FormatAll 格式化平台信息
// 4. 返回格式化后的字符串列表
//
// 平台格式示例:
//   - "linux/amd64"
//   - "linux/arm64"
//   - "linux/arm/v7"
func formatPlatforms(p []ocispecs.Platform) []string {
	// 创建字符串切片，预分配容量以提高性能
	str := make([]string, 0, len(p))

	// 遍历平台列表
	for _, pp := range p {
		// 规范化平台信息
		// platforms.Normalize 会处理平台信息的标准化
		// platforms.FormatAll 会将平台信息格式化为字符串
		str = append(str, platforms.FormatAll(platforms.Normalize(pp)))
	}

	return str
}

// parseArch 解析架构参数字符串
//
// 参数:
//
//	in: 输入的架构字符串，可以是单个架构或多个架构（逗号分隔）
//
// 返回值:
//
//	[]string: 解析后的架构名称列表
//
// 工作原理:
// 1. 如果输入为空，返回空列表
// 2. 按逗号分割输入字符串
// 3. 对每个部分尝试解析为平台规格
// 4. 如果解析成功，提取架构名称
// 5. 如果解析失败，直接使用原始字符串
//
// 支持的输入格式:
//   - 单个架构: "arm64"
//   - 多个架构: "arm64,amd64,arm"
//   - 平台规格: "linux/arm64"
//
// 注意:
//   - 平台规格会被简化为架构名称
//   - 无效的输入会被原样保留
func parseArch(in string) (out []string) {
	// 如果输入为空，返回空列表
	if in == "" {
		return
	}

	// 按逗号分割输入字符串
	for _, v := range strings.Split(in, ",") {
		// 尝试解析为平台规格
		p, err := platforms.Parse(v)
		if err != nil {
			// 解析失败，直接使用原始字符串
			out = append(out, v)
		} else {
			// 解析成功，提取架构名称
			out = append(out, p.Architecture)
		}
	}

	return
}

// parseUninstall 解析卸载参数字符串
//
// 参数:
//
//	in: 输入的卸载字符串，可以是单个架构或多个架构（逗号分隔）
//
// 返回值:
//
//	[]string: 解析后的卸载目标列表
//
// 工作原理:
// 1. 如果输入为空，返回空列表
// 2. 按逗号分割输入字符串
// 3. 对每个部分尝试解析为平台规格
// 4. 如果解析成功且配置存在，转换为 QEMU 模拟器名称
// 5. 使用 glob 模式匹配查找匹配的配置文件
// 6. 收集所有匹配的配置文件名称
//
// 支持的输入格式:
//   - 架构名称: "arm64"
//   - QEMU 模拟器名称: "qemu-aarch64"
//   - 多个目标: "arm64,amd64"
//
// 注意:
//   - 支持使用 glob 模式匹配（如 "qemu-*"）
//   - 会查找所有匹配的配置文件
func parseUninstall(in string) (out []string) {
	// 如果输入为空，返回空列表
	if in == "" {
		return
	}

	// 按逗号分割输入字符串
	for _, v := range strings.Split(in, ",") {
		// 尝试解析为平台规格
		if p, err := platforms.Parse(v); err == nil {
			// 检查配置是否存在
			if c, ok := configs[p.Architecture]; ok {
				// 将架构名称转换为 QEMU 模拟器名称
				// 例如: "arm64" -> "aarch64"
				v = strings.TrimPrefix(c.binary, "qemu-")
			}
		}

		// 使用 glob 模式匹配查找配置文件
		// 这允许使用通配符进行匹配
		fis, err := filepath.Glob(filepath.Join(mount, v))
		if err != nil || len(fis) == 0 {
			// 没有找到匹配的文件，直接使用原始字符串
			out = append(out, v)
		}

		// 收集所有匹配的配置文件名称
		for _, fi := range fis {
			// 提取文件名（去掉路径）
			out = append(out, filepath.Base(fi))
		}
	}

	return
}

// main 程序入口函数
//
// 工作流程:
// 1. 设置日志格式（不显示时间戳）
// 2. 解析命令行参数
// 3. 调用 run 函数执行主要逻辑
// 4. 如果发生错误，输出错误信息
//
// 注意:
//   - 日志不显示时间戳，使输出更简洁
//   - 错误信息使用 %+v 格式，包含完整的错误堆栈
func main() {
	// 设置日志格式
	// 不显示时间戳，使输出更简洁
	log.SetFlags(0)

	// 解析命令行参数
	flag.Parse()

	// 执行主要逻辑
	if err := run(); err != nil {
		// 如果发生错误，输出错误信息
		log.Printf("error: %+v", err)
	}
}

// run 执行程序的主要逻辑
//
// 返回值:
//
//	error: 如果执行过程中发生错误返回错误，成功返回 nil
//
// 工作流程:
// 1. 如果指定了 -version 参数，显示版本信息并退出
// 2. 检查 binfmt_misc 是否已挂载，如果未挂载则挂载
// 3. 执行卸载操作（如果指定了 -uninstall 参数）
// 4. 执行安装操作（如果指定了 -install 参数）
// 5. 打印当前状态
//
// 注意:
//   - 如果 binfmt_misc 未挂载，程序会尝试挂载它
//   - 程序退出时会自动卸载 binfmt_misc（如果是由程序挂载的）
//   - 安装和卸载操作会分别报告每个操作的结果
func run() error {
	// 检查是否需要显示版本信息
	if flVersion {
		// 输出版本信息
		// 格式: binfmt/{revision} qemu/{version} go/{version}
		// runtime.Version()[2:] 用于去掉 "go" 前缀
		log.Printf("binfmt/%s qemu/%s go/%s", revision, qemuVersion, runtime.Version()[2:])
		return nil
	}

	// 检查 binfmt_misc 是否已挂载
	// 通过检查 status 文件是否存在来判断
	if _, err := os.Stat(filepath.Join(mount, "status")); err != nil {
		// binfmt_misc 未挂载，尝试挂载
		// syscall.Mount 参数:
		//   - "binfmt_misc": 源设备名称
		//   - mount: 目标挂载点
		//   - "binfmt_misc": 文件系统类型
		//   - 0: 挂载标志
		//   - "": 挂载选项
		if err := syscall.Mount("binfmt_misc", mount, "binfmt_misc", 0, ""); err != nil {
			return errors.Wrapf(err, "cannot mount binfmt_misc filesystem at %s", mount)
		}

		// 注册 defer 函数，在程序退出时卸载 binfmt_misc
		// 这样可以确保不会在系统中留下挂载点
		defer syscall.Unmount(mount, 0)
	}

	// 执行卸载操作
	// 遍历所有需要卸载的架构
	for _, name := range parseUninstall(toUninstall) {
		// 尝试卸载
		err := uninstall(name)
		if err == nil {
			// 卸载成功
			log.Printf("uninstalling: %s OK", name)
		} else {
			// 卸载失败
			log.Printf("uninstalling: %s %v", name, err)
		}
	}

	// 确定要安装的架构列表
	var installArchs []string
	if toInstall == "all" {
		// 如果指定了 "all"，安装所有支持的架构
		installArchs = allArch()
	} else {
		// 否则，解析用户指定的架构列表
		installArchs = parseArch(toInstall)
	}

	// 执行安装操作
	// 遍历所有需要安装的架构
	for _, name := range installArchs {
		// 尝试安装
		err := install(name)
		if err == nil {
			// 安装成功
			log.Printf("installing: %s OK", name)
		} else {
			// 安装失败
			log.Printf("installing: %s %v", name, err)
		}
	}

	// 打印当前状态
	// 显示系统支持的架构和已安装的模拟器
	return printStatus()
}
