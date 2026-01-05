// 包 main 是一个测试程序
// 用于测试 exec.Cmd 中 argv0 的行为
// 这个测试验证了如何正确设置 exec.Cmd 的 Path 和 Args 字段
// 这对于 binfmt 工具很重要，因为它需要正确执行不同架构的二进制文件
package main

import (
	"errors"        // 用于错误处理
	"flag"          // 用于解析命令行参数
	"log"           // 用于日志输出
	"os"            // 用于操作系统相关操作
	"os/exec"       // 用于执行外部命令
	"path/filepath" // 用于文件路径操作
	"strings"       // 用于字符串操作
)

// main 函数是程序的入口点
// 调用 run 函数执行主要逻辑，如果发生错误则打印错误信息并退出
func main() {
	if err := run(); err != nil {
		// 使用 %+v 格式化错误信息，包含堆栈跟踪
		log.Printf("%+v", err)
		os.Exit(1)
	}
}

// run 函数执行程序的主要逻辑
// 功能:
//  1. 解析命令行参数
//  2. 验证参数数量（至少需要 2 个参数）
//  3. 创建并配置 exec.Cmd
//  4. 根据第一个参数的类型（绝对路径、相对路径或命令名）设置 cmd.Path
//  5. 执行命令
//
// 返回值:
//
//	error: 如果执行过程中发生错误返回错误，成功返回 nil
//
// 使用方法:
//
//	./execargv0 <argv0> <arg1> <arg2> ...
//
// 参数:
//
//	argv0: 要执行的程序路径或命令名
//	arg1, arg2, ...: 传递给程序的参数
//
// 注意:
//   - argv0 是程序的实际路径，而 Args[0] 是程序在参数列表中显示的名称
//   - 这个测试验证了如何正确设置 Path 和 Args 以确保程序正确执行
func run() error {
	// 解析命令行参数
	// flag.Parse() 会解析所有以 - 开头的参数
	// 剩余的参数可以通过 flag.Args() 获取
	flag.Parse()

	// 检查参数数量
	// 至少需要 2 个参数：argv0 和至少一个程序参数
	if len(flag.Args()) < 2 {
		return errors.New("at least 2 arguments required")
	}

	// 创建 exec.Cmd 结构体
	// Args 字段包含传递给程序的参数列表
	// Args[0] 通常是程序名称，但在某些情况下可能与 Path 不同
	cmd := &exec.Cmd{
		Args: flag.Args()[1:], // 跳过第一个参数（argv0），只传递程序参数
	}

	// 获取第一个参数作为 argv0
	// argv0 是要执行的程序的实际路径或命令名
	argv0 := flag.Arg(0)

	// 根据 argv0 的类型设置 cmd.Path
	// cmd.Path 是要执行的程序的完整路径
	// 这是 exec.Cmd 的关键字段，决定了实际执行哪个程序

	// 情况 1: argv0 是绝对路径
	// 例如: /usr/bin/ls
	if filepath.IsAbs(argv0) {
		cmd.Path = argv0
	} else if strings.HasPrefix(argv0, "./") {
		// 情况 2: argv0 是相对路径（以 ./ 开头）
		// 例如: ./myprogram
		// 将相对路径转换为绝对路径
		p, err := filepath.Abs(argv0)
		if err != nil {
			return err
		}
		cmd.Path = p
	} else {
		// 情况 3: argv0 是命令名（不带路径）
		// 例如: ls, echo, cat
		// 使用 exec.LookPath 在 PATH 环境变量中查找命令
		p, err := exec.LookPath(argv0)
		if err != nil {
			return err
		}
		cmd.Path = p
	}

	// 设置标准输出和标准错误输出
	// 将子进程的输出重定向到当前进程的输出
	// 这样可以看到子程序的输出
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// 执行命令
	// cmd.Run() 会启动进程并等待它完成
	// 如果命令成功执行（退出码为 0），返回 nil
	// 如果命令执行失败或返回非零退出码，返回错误
	return cmd.Run()
}
