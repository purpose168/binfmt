// 包 main 是一个测试程序
// 用于验证在改变工作目录后，/proc/self/exe 是否仍然指向正确的可执行文件
// 这个测试对于 binfmt 工具很重要，因为 binfmt 需要在不同工作目录下正确识别和执行二进制文件
package main

import (
	"bytes"      // 用于缓冲区操作
	"crypto/md5" // 用于计算 MD5 哈希值
	"fmt"        // 用于格式化输出
	"os"         // 用于操作系统相关操作
)

// main 函数是程序的入口点
// 执行流程:
// 1. 改变工作目录到 /tmp
// 2. 读取并打印 /proc/self/exe 的符号链接路径
// 3. 计算 /proc/self/exe 的 MD5 哈希值
// 4. 计算命令行参数指定文件的 MD5 哈希值
// 5. 比较两个哈希值，验证它们是否匹配
//
// 用途:
//   - 测试 binfmt 在改变工作目录后是否能正确识别可执行文件
//   - 验证 /proc/self/exe 在不同工作目录下的行为
//   - 确保 binfmt 不会因为工作目录改变而错误识别可执行文件
//
// 使用方法:
//
//	./chwd <expected-executable-path>
//
// 参数:
//
//	os.Args[1]: 预期的可执行文件路径，用于与 /proc/self/exe 进行比较
func main() {
	// 改变当前工作目录到 /tmp
	// 这是为了测试在改变工作目录后，/proc/self/exe 是否仍然指向正确的可执行文件
	// 如果 binfmt 在处理 /proc/self/exe 时使用了相对路径，这可能会导致问题
	if err := os.Chdir("/tmp"); err != nil {
		// 如果改变目录失败，打印错误信息并退出
		fmt.Println(err)
		os.Exit(1)
	}

	// 读取 /proc/self/exe 的符号链接
	// /proc/self/exe 是一个特殊的符号链接，指向当前进程的可执行文件
	// 在 Linux 系统中，这个链接总是指向实际的可执行文件，无论工作目录如何
	if p, err := os.Readlink("/proc/self/exe"); err != nil {
		// 如果读取符号链接失败，打印错误信息并退出
		fmt.Println(err)
		os.Exit(1)
	} else {
		// 打印符号链接指向的路径
		// 这有助于调试和验证 /proc/self/exe 是否指向正确的文件
		fmt.Println(p)
	}

	// 打开 /proc/self/exe 文件
	// 这会打开实际的可执行文件，而不是符号链接本身
	// 我们需要读取文件内容来计算哈希值
	f, err := os.Open("/proc/self/exe")
	if err != nil {
		// 如果打开文件失败，打印错误信息并退出
		fmt.Println(err)
		os.Exit(1)
	}
	// 使用 defer 确保文件在函数返回前关闭
	// 这是 Go 的资源管理模式，确保资源被正确释放
	defer f.Close()

	// 创建一个缓冲区用于存储文件内容
	var buf bytes.Buffer
	// 从 /proc/self/exe 读取所有内容到缓冲区
	// ReadFrom 会读取直到 EOF 或发生错误
	buf.ReadFrom(f)

	// 计算缓冲区内容的 MD5 哈希值
	// MD5 哈希用于验证文件内容的完整性
	hash := md5.Sum(buf.Bytes())

	// 打开命令行参数指定的文件
	// 这个文件应该是预期的可执行文件路径
	// 我们将比较这个文件与 /proc/self/exe 的哈希值
	f2, err := os.Open(os.Args[1])
	if err != nil {
		// 如果打开文件失败，打印错误信息并退出
		fmt.Println(err)
		os.Exit(1)
	}

	// 重置缓冲区，清空之前的内容
	// 这样可以复用同一个缓冲区来读取新文件
	buf.Reset()
	// 从命令行参数指定的文件读取所有内容到缓冲区
	buf.ReadFrom(f2)

	// 计算第二个文件的 MD5 哈希值
	hash2 := md5.Sum(buf.Bytes())

	// 比较两个哈希值
	// 如果哈希值不匹配，说明 /proc/self/exe 指向的文件与预期不符
	if hash != hash2 {
		// 打印错误信息，指出 /proc/self/exe 与预期文件不匹配
		// 这可能意味着 binfmt 在改变工作目录后错误地识别了可执行文件
		fmt.Printf("/proc/self/exe does not match %s\n", os.Args[1])
		os.Exit(1)
	}

	// 如果哈希值匹配，说明测试通过
	// 退出码 0 表示成功
	os.Exit(0)
}
