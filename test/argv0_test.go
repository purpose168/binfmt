// 包 tests 包含 binfmt 工具的测试用例
// 这些测试用于验证 binfmt 在不同场景下的行为和正确性
// argv0_test.go 专门测试 argv0（程序名参数）的处理机制
package tests

import (
	"fmt"     // 用于格式化输出
	"os"      // 用于操作系统相关操作和环境变量访问
	"os/exec" // 用于执行外部命令
	"strings" // 用于字符串操作
	"testing" // 用于编写测试用例

	"github.com/stretchr/testify/require" // 提供更强大的测试断言函数
)

// init 函数在包初始化时自动执行
// 功能: 检查是否作为子进程被调用，如果是则打印参数并退出
//
// 工作原理:
//  1. 检查环境变量 BINFMT_ARGV0_TEST 是否存在
//  2. 如果存在，说明这是被测试函数启动的子进程
//  3. 打印所有命令行参数，用逗号分隔
//  4. 退出程序（退出码 0）
//
// 用途:
//   - 允许同一个可执行文件既作为测试运行器，又作为被测试的子进程
//   - 验证子进程接收到的参数是否正确
//   - 测试 argv0 的传递机制
//
// 注意:
//   - 这个函数只在包加载时执行一次
//   - 只有设置了 BINFMT_ARGV0_TEST 环境变量时才会执行特殊逻辑
//   - 正常测试运行时，这个函数会检查环境变量并立即返回
func init() {
	// 检查环境变量 BINFMT_ARGV0_TEST 是否存在且不为空
	// 如果存在，说明这是被测试函数启动的子进程
	if v := os.Getenv("BINFMT_ARGV0_TEST"); v != "" {
		// 打印所有命令行参数，用逗号分隔
		// 例如: os.Args = ["first", "second", "third"]
		// 输出: first,second,third
		fmt.Println(strings.Join(os.Args, ","))
		// 退出程序，退出码为 0 表示成功
		os.Exit(0)
	}
}

// TestArgv0 测试 argv0 的传递机制
// 功能: 验证 exec.Cmd 的 Args 字段是否正确传递给子进程
//
// 测试流程:
//  1. 确定要执行的可执行文件路径（默认为 /proc/self/exe）
//  2. 创建 exec.Cmd，设置 Path、Env 和 Args
//  3. 执行命令并捕获输出
//  4. 验证输出是否为预期的参数列表
//
// 测试目的:
//   - 验证 Args 字段是否正确传递给子进程
//   - 确认子进程的 os.Args 是否与设置的 Args 一致
//   - 测试 binfmt 在不同架构下的参数传递
//
// 注意:
//   - Args[0] 是子进程看到的程序名
//   - 这个测试不设置 Path 为实际路径，而是使用 /proc/self/exe
//   - 通过环境变量 REEXEC_NAME 可以覆盖默认的可执行文件路径
func TestArgv0(t *testing.T) {
	// 确定要执行的可执行文件路径
	// 默认使用 /proc/self/exe，这是一个特殊的符号链接，指向当前进程的可执行文件
	self := "/proc/self/exe"

	// 检查环境变量 REEXEC_NAME 是否存在
	// 如果存在，使用该环境变量的值作为可执行文件路径
	// 这允许测试指定特定的可执行文件进行测试
	if v, ok := os.LookupEnv("REEXEC_NAME"); ok {
		self = v
	}

	// 创建 exec.Cmd 结构体
	// Path: 要执行的可执行文件路径
	// Env: 环境变量列表，设置 BINFMT_ARGV0_TEST=1 触发子进程的特殊逻辑
	// Args: 传递给子进程的参数列表
	cmd := &exec.Cmd{
		Path: self,
		Env:  []string{"BINFMT_ARGV0_TEST=1"},
		Args: []string{"first", "second", "third"},
	}

	// 执行命令并捕获标准输出和标准错误输出
	// CombinedOutput 会执行命令并返回所有输出
	// 如果命令执行成功（退出码为 0），out 包含输出内容
	// 如果命令执行失败，out 包含错误信息，err 为非 nil
	out, err := cmd.CombinedOutput()

	// 验证输出是否为预期的参数列表
	// 子进程会打印 "first,second,third\n"
	// require.Equal 会在断言失败时立即终止测试
	require.Equal(t, "first,second,third\n", string(out))

	// 验证命令是否成功执行
	// require.NoError 会在 err 为非 nil 时终止测试
	require.NoError(t, err)
}
