// 包 main 是 binfmt 工具的主包
// binfmt 是一个用于管理 Linux binfmt_misc 的工具
// 它允许系统通过 QEMU 模拟器执行不同架构的二进制文件
package main

// 版本信息变量
// 这些变量在构建时通过 -ldflags 注入实际的值
// 用于在运行时显示应用程序的版本信息
var (
	// revision 表示应用程序的 Git 修订版本号
	// 默认值为 "unknown"，在构建时会被实际的 Git commit hash 替换
	// 格式示例: "a1b2c3d4e5f6g7h8i9j0"
	// 用途:
	//   - 帮助用户识别正在运行的代码版本
	//   - 便于问题追踪和调试
	//   - 在报告问题时提供精确的版本信息
	revision = "unknown"

	// qemuVersion 表示 QEMU 模拟器的版本号
	// 默认值为 "unknown"，在构建时会被实际的 QEMU 版本替换
	// 格式示例: "7.2.0"
	// 用途:
	//   - 显示当前使用的 QEMU 版本
	//   - 帮助诊断与 QEMU 相关的问题
	//   - 确保用户知道正在使用哪个版本的模拟器
	// 注意:
	//   - QEMU 是 binfmt 工具的核心依赖，用于模拟不同架构的 CPU
	//   - 不同版本的 QEMU 可能支持不同的架构和特性
	qemuVersion = "unknown"
)
