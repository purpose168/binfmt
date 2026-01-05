// 包 tests 包含 binfmt 工具的测试用例
// sched.go 提供了 Linux 调度器相关的系统调用封装
// 这些函数用于控制和查询进程的调度策略和参数
// 这对于测试 binfmt 在不同调度策略下的行为很重要
package tests

import (
	"syscall" // 用于系统调用相关的类型和错误
	"unsafe"  // 用于不安全的指针操作，用于与 C 代码交互

	"golang.org/x/sys/unix" // 提供对 Unix 系统调用的访问
)

// CGO 导入部分
// #include <linux/sched.h>: Linux 调度器头文件，包含调度策略和参数的定义
// #include <linux/sched/types.h>: Linux 调度器类型头文件，包含调度属性的定义
// typedef struct sched_param sched_param: 为 C 的 sched_param 结构体定义 Go 类型别名
import "C"

// Policy 类型表示进程的调度策略
// 调度策略决定了内核如何选择下一个运行的进程
// 不同的策略适用于不同类型的应用程序
type Policy uint32

// 调度策略常量
// 这些常量对应 Linux 内核中定义的调度策略
const (
	// SCHED_NORMAL 是标准的分时调度策略
	// 这是普通进程的默认调度策略
	// 特点:
	//   - 使用完全公平调度器（CFS）
	//   - 适合交互式和批处理任务
	//   - 优先级通过 nice 值调整（-20 到 19）
	SCHED_NORMAL Policy = C.SCHED_NORMAL

	// SCHED_FIFO 是实时先入先出调度策略
	// 用于硬实时任务，需要确定性的执行时间
	// 特点:
	//   - 同优先级的进程按 FIFO 顺序执行
	//   - 高优先级进程会抢占低优先级进程
	//   - 进程会一直运行直到阻塞或自愿放弃 CPU
	//   - 需要 root 权限或 CAP_SYS_NICE 能力
	SCHED_FIFO Policy = C.SCHED_FIFO

	// SCHED_RR 是实时轮转调度策略
	// 用于软实时任务，需要公平性但仍然保证实时性
	// 特点:
	//   - 同优先级的进程按时间片轮转执行
	//   - 高优先级进程会抢占低优先级进程
	//   - 每个进程有一个时间片，用完后放回队列末尾
	//   - 需要 root 权限或 CAP_SYS_NICE 能力
	SCHED_RR Policy = C.SCHED_RR

	// SCHED_BATCH 是批处理调度策略
	// 用于 CPU 密集型任务，不需要交互性
	// 特点:
	//   - 类似于 SCHED_NORMAL，但会给予更长的 CPU 时间片
	//   - 减少上下文切换，提高吞吐量
	//   - 适合长时间运行的计算任务
	//   - 不会抢占交互式进程
	SCHED_BATCH Policy = C.SCHED_BATCH

	// SCHED_IDLE 是空闲调度策略
	// 用于优先级极低的后台任务
	// 特点:
	//   - 只有当 CPU 完全空闲时才运行
	//   - 优先级低于所有其他调度策略
	//   - 适合不影响系统性能的后台任务
	//   - nice 值固定为 19（最低优先级）
	SCHED_IDLE Policy = C.SCHED_IDLE

	// SCHED_DEADLINE 是截止时间调度策略
	// 用于硬实时任务，有严格的执行时间要求
	// 特点:
	//   - 基于 EDF（最早截止时间优先）算法
	//   - 需要指定运行时间、截止时间和周期
	//   - 适合有严格时间约束的实时应用
	//   - 需要 root 权限或 CAP_SYS_NICE 能力
	SCHED_DEADLINE Policy = C.SCHED_DEADLINE
)

// SchedFlag 类型表示调度器的标志位
// 这些标志用于修改调度器的行为
type SchedFlag int

// 调度器标志常量
const (
	// SCHED_FLAG_RESET_ON_FORK 表示在 fork 时重置调度策略
	// 当进程创建子进程时，子进程将重置为 SCHED_NORMAL 策略
	// 用途:
	//   - 防止子进程继承父进程的实时调度策略
	//   - 避免子进程占用过多 CPU 资源
	//   - 提高系统的安全性和稳定性
	SCHED_FLAG_RESET_ON_FORK SchedFlag = C.SCHED_FLAG_RESET_ON_FORK

	// SCHED_FLAG_RECLAIM 表示启用带宽回收
	// 允许调度器回收未使用的 CPU 时间
	// 用途:
	//   - 提高 CPU 利用率
	//   - 允许实时任务在未使用其分配的时间时，其他任务可以使用
	//   - 主要用于 SCHED_DEADLINE 策略
	SCHED_FLAG_RECLAIM SchedFlag = C.SCHED_FLAG_RECLAIM

	// SCHED_FLAG_DL_OVERRUN 表示检测截止时间溢出
	// 当任务超过其截止时间时，会发送信号
	// 用途:
	//   - 监控实时任务是否满足时间约束
	//   - 帮助调试实时系统
	//   - 主要用于 SCHED_DEADLINE 策略
	SCHED_FLAG_DL_OVERRUN SchedFlag = C.SCHED_FLAG_DL_OVERRUN
)

// SchedParam 类型表示调度参数
// 对应 Linux 内核中的 struct sched_param
type SchedParam C.sched_param

// SchedGetScheduler 获取指定进程的调度策略
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//
// 返回值:
//
//	Policy: 进程的调度策略
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 查询进程当前使用的调度策略
//   - 验证调度策略是否正确设置
//   - 调试调度相关问题
//
// 注意:
//   - 需要 CAP_SYS_NICE 能力才能查询其他进程的调度策略
//   - 对于实时策略，返回值可能是 SCHED_FIFO 或 SCHED_RR
func SchedGetScheduler(pid int) (Policy, error) {
	// 调用 SYS_SCHED_GETSCHEDULER 系统调用
	// 参数: pid, 0, 0
	// 返回值: 调度策略
	r0, _, e1 := unix.Syscall(unix.SYS_SCHED_GETSCHEDULER, uintptr(pid), 0, 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return 0, syscall.Errno(e1)
	}
	// 返回调度策略
	return Policy(r0), nil
}

// SchedSetScheduler 设置指定进程的调度策略和参数
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//	p: 要设置的调度策略
//	param: 调度参数，对于实时策略包含优先级
//
// 返回值:
//
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 改变进程的调度策略
//   - 设置实时进程的优先级
//   - 优化进程的调度行为
//
// 注意:
//   - 设置实时策略（SCHED_FIFO、SCHED_RR、SCHED_DEADLINE）需要 root 权限或 CAP_SYS_NICE 能力
//   - 设置实时策略会影响系统响应性，应谨慎使用
//   - 对于 SCHED_NORMAL、SCHED_BATCH、SCHED_IDLE，param 中的优先级通常被忽略
func SchedSetScheduler(pid int, p Policy, param SchedParam) error {
	// 调用 SYS_SCHED_SETSCHEDULER 系统调用
	// 参数: pid, policy, param
	// 返回值: 成功返回 0，失败返回错误码
	_, _, e1 := unix.Syscall(unix.SYS_SCHED_SETSCHEDULER, uintptr(pid), uintptr(p), uintptr(unsafe.Pointer(&param)))
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return syscall.Errno(e1)
	}
	return nil
}

// SchedGetPriorityMin 获取指定调度策略的最小优先级
//
// 参数:
//
//	p: 调度策略
//
// 返回值:
//
//	int: 该策略的最小优先级值
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 查询调度策略的优先级范围
//   - 验证优先级设置是否有效
//   - 了解不同策略的优先级限制
//
// 注意:
//   - 对于 SCHED_FIFO 和 SCHED_RR，返回 1
//   - 对于其他策略，返回 0（因为这些策略不使用静态优先级）
func SchedGetPriorityMin(p Policy) (int, error) {
	// 调用 SYS_SCHED_GET_PRIORITY_MIN 系统调用
	// 参数: policy, 0, 0
	// 返回值: 最小优先级
	r0, _, e1 := unix.Syscall(unix.SYS_SCHED_GET_PRIORITY_MIN, uintptr(p), 0, 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return 0, syscall.Errno(e1)
	}
	// 返回最小优先级
	return int(r0), nil
}

// SchedGetPriorityMax 获取指定调度策略的最大优先级
//
// 参数:
//
//	p: 调度策略
//
// 返回值:
//
//	int: 该策略的最大优先级值
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 查询调度策略的优先级范围
//   - 验证优先级设置是否有效
//   - 了解不同策略的优先级限制
//
// 注意:
//   - 对于 SCHED_FIFO 和 SCHED_RR，返回 99（默认值，可通过 /proc/sys/kernel/sched_rt_priority_max 修改）
//   - 对于其他策略，返回 0（因为这些策略不使用静态优先级）
func SchedGetPriorityMax(p Policy) (int, error) {
	// 调用 SYS_SCHED_GET_PRIORITY_MAX 系统调用
	// 参数: policy, 0, 0
	// 返回值: 最大优先级
	r0, _, e1 := unix.Syscall(unix.SYS_SCHED_GET_PRIORITY_MAX, uintptr(p), 0, 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return 0, syscall.Errno(e1)
	}
	// 返回最大优先级
	return int(r0), nil
}

// SchedYield 主动让出 CPU
// 当前进程自愿放弃 CPU，让其他进程运行
//
// 返回值:
//
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 在繁忙等待中避免占用 CPU
//   - 实现协作式多任务
//   - 提高系统响应性
//
// 注意:
//   - 如果没有其他可运行进程，当前进程会继续运行
//   - 这个调用不会改变进程的调度策略
//   - 对于实时进程，这个调用可能不会立即生效
func SchedYield() error {
	// 调用 SYS_SCHED_YIELD 系统调用
	// 参数: 0, 0, 0
	// 返回值: 成功返回 0，失败返回错误码
	_, _, e1 := unix.Syscall(unix.SYS_SCHED_YIELD, 0, 0, 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return syscall.Errno(e1)
	}
	return nil
}

// SchedGetParam 获取指定进程的调度参数
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//
// 返回值:
//
//	SchedParam: 调度参数，对于实时策略包含优先级
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 查询进程的调度参数
//   - 获取实时进程的优先级
//   - 验证调度参数是否正确设置
//
// 注意:
//   - 对于 SCHED_NORMAL、SCHED_BATCH、SCHED_IDLE，返回的参数可能不包含有用信息
//   - 对于 SCHED_FIFO 和 SCHED_RR，返回的参数包含静态优先级
func SchedGetParam(pid int) (SchedParam, error) {
	// 创建调度参数结构体
	var param SchedParam
	// 调用 SYS_SCHED_GETPARAM 系统调用
	// 参数: pid, param, 0
	// 返回值: 成功返回 0，失败返回错误码
	_, _, e1 := unix.Syscall(unix.SYS_SCHED_GETPARAM, uintptr(pid), uintptr(unsafe.Pointer(&param)), 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return param, syscall.Errno(e1)
	}
	// 返回调度参数
	return param, nil
}

// SchedSetParam 设置指定进程的调度参数
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//	param: 调度参数，对于实时策略包含优先级
//
// 返回值:
//
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 修改进程的调度参数
//   - 调整实时进程的优先级
//   - 优化进程的调度行为
//
// 注意:
//   - 这个函数不会改变进程的调度策略，只修改参数
//   - 对于 SCHED_NORMAL、SCHED_BATCH、SCHED_IDLE，参数通常被忽略
//   - 设置实时优先级需要 root 权限或 CAP_SYS_NICE 能力
func SchedSetParam(pid int, param SchedParam) error {
	// 调用 SYS_SCHED_SETPARAM 系统调用
	// 参数: pid, param, 0
	// 返回值: 成功返回 0，失败返回错误码
	_, _, e1 := unix.Syscall(unix.SYS_SCHED_SETPARAM, uintptr(pid), uintptr(unsafe.Pointer(&param)), 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return syscall.Errno(e1)
	}
	return nil
}

// SchedAttr 类型表示扩展的调度属性
// 对应 Linux 内核中的 struct sched_attr
// 提供了比 SchedParam 更详细的调度控制
type SchedAttr struct {
	Size          uint32 // 结构体大小，用于版本控制
	SchedPolicy   Policy // 调度策略
	SchedFlags    uint64 // 调度标志
	SchedNice     uint32 // nice 值（-20 到 19），用于 SCHED_NORMAL、SCHED_BATCH、SCHED_IDLE
	SchedPriority uint32 // 静态优先级（1 到 99），用于 SCHED_FIFO、SCHED_RR
	SchedRuntime  uint64 // 运行时间（纳秒），用于 SCHED_DEADLINE
	SchedDeadline uint64 // 截止时间（纳秒），用于 SCHED_DEADLINE
	SchedPeriod   uint64 // 周期（纳秒），用于 SCHED_DEADLINE
	SchedUtilMin  uint32 // 最小 CPU 利用率（0 到 1024），用于 CFS 带宽控制
	SchedUtilMax  uint32 // 最大 CPU 利用率（0 到 1024），用于 CFS 带宽控制
}

// SchedGetAttr 获取指定进程的扩展调度属性
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//
// 返回值:
//
//	SchedAttr: 扩展的调度属性
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 查询进程的详细调度信息
//   - 获取 SCHED_DEADLINE 策略的运行时间和截止时间
//   - 了解进程的 CPU 利用率限制
//
// 注意:
//   - 这个函数比 SchedGetParam 提供更多信息
//   - 需要内核支持扩展调度属性（Linux 3.14+）
//   - 查询其他进程的属性需要 CAP_SYS_NICE 能力
func SchedGetAttr(pid int) (SchedAttr, error) {
	// 创建调度属性结构体
	var attr SchedAttr
	// 调用 SYS_SCHED_GETATTR 系统调用
	// 参数: pid, attr, size, 0, 0, 0
	// 返回值: 成功返回 0，失败返回错误码
	_, _, e1 := unix.Syscall6(unix.SYS_SCHED_GETATTR, uintptr(pid), uintptr(unsafe.Pointer(&attr)), unsafe.Sizeof(SchedAttr{}), 0, 0, 0)
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return attr, syscall.Errno(e1)
	}
	// 返回调度属性
	return attr, nil
}

// SchedSetAttr 设置指定进程的扩展调度属性
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//	attr: 扩展的调度属性
//	flags: 调度标志
//
// 返回值:
//
//	error: 如果调用失败返回错误，成功返回 nil
//
// 用途:
//   - 设置进程的详细调度参数
//   - 配置 SCHED_DEADLINE 策略的运行时间和截止时间
//   - 设置 CPU 利用率限制
//
// 注意:
//   - 这个函数比 SchedSetParam 提供更多控制选项
//   - 需要内核支持扩展调度属性（Linux 3.14+）
//   - 设置实时策略需要 root 权限或 CAP_SYS_NICE 能力
func SchedSetAttr(pid int, attr SchedAttr, flags SchedFlag) error {
	// 设置结构体大小，用于版本控制
	attr.Size = uint32(unsafe.Sizeof(attr))
	// 调用内部函数设置调度属性
	return schedSetAttr(pid, unsafe.Pointer(&attr), flags)
}

// schedSetAttr 设置指定进程的扩展调度属性的内部函数
//
// 参数:
//
//	pid: 进程 ID，0 表示当前进程
//	attr: 扩展的调度属性的指针
//	flags: 调度标志
//
// 返回值:
//
//	error: 如果调用失败返回错误，成功返回 nil
//
// 注意:
//   - 这是一个内部函数，使用 unsafe.Pointer
//   - 调用者需要确保 attr.Size 已正确设置
func schedSetAttr(pid int, attr unsafe.Pointer, flags SchedFlag) error {
	// 调用 SYS_SCHED_SETATTR 系统调用
	// 参数: pid, attr, flags
	// 返回值: 成功返回 0，失败返回错误码
	_, _, e1 := unix.Syscall(unix.SYS_SCHED_SETATTR, uintptr(pid), uintptr(attr), uintptr(flags))
	if e1 != 0 {
		// 如果系统调用失败，返回错误
		return syscall.Errno(e1)
	}
	return nil
}
