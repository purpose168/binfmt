// 包 main 是一个测试程序
// 用于打印程序接收到的所有命令行参数
// 这个测试对于 binfmt 工具很重要，因为它可以验证参数是否正确传递给被模拟的程序
// 通过打印参数，可以调试和验证 binfmt 的参数传递机制
package main

import (
	"fmt"     // 用于格式化输出
	"os"      // 用于访问命令行参数
	"strings" // 用于字符串操作
)

// main 函数是程序的入口点
// 功能: 打印所有命令行参数，用空格分隔
//
// 输出格式:
//
//	参数之间用单个空格连接
//	例如: ./printargs arg1 arg2 arg3
//	输出: ./printargs arg1 arg2 arg3
//
// 用途:
//   - 验证命令行参数是否正确传递
//   - 调试参数传递问题
//   - 测试 binfmt 在不同架构下的参数处理
//   - 确认 argv[0]（程序名）和其他参数的正确性
//
// 注意:
//   - os.Args[0] 是程序本身的路径或名称
//   - os.Args[1:] 是传递给程序的实际参数
//   - 这个程序会打印所有参数，包括程序名
func main() {
	// 打印所有命令行参数
	// strings.Join(os.Args, " ") 将参数数组用空格连接成一个字符串
	// fmt.Println 打印字符串并添加换行符
	//
	// 示例:
	//   执行: ./printargs hello world
	//   os.Args = ["./printargs", "hello", "world"]
	//   输出: ./printargs hello world
	fmt.Println(strings.Join(os.Args, " "))
}
